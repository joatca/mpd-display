/*
This file is part of MPD Display - an MPD status display for viewing across a room

Copyright (C) 2021 Fraser McCrossan

MPD Display is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data_classes.dart';

/* this data class connects to an MPD server and sends play state data on the supplied stream */

enum ConnState {
  connecting, // we have just connected and we're waiting for a response
  idle, // we sent the idle command and are waiting for a response
  readstate, // we sent commands to fetch the state and are waiting for a response
  command, // we sent a command (like play) and are waiting for a response
}

class MPDClient {
  static const minRetryInterval = 1;
  static const maxRetryInterval = 5;
  static const retryIncrement = 1;
  Timer? retryTimer;
  var retryInterval = minRetryInterval;
  String server;
  int port;
  Socket? socket;
  ConnState connstate = ConnState.connecting;
  bool stayConnected = false; // whether to reconnect on failure/disconnect
  late StreamController<Info> controller;
  final utf8 = const Utf8Codec(allowMalformed: true);

  MPDClient([this.server = "music", this.port = 6600]) {
    controller = StreamController<Info>(
        onListen: connect,
        onPause: disconnect,
        onResume: connect,
        onCancel: disconnect);
    getServer(); // asynchronously fetches server information
  }

  Stream<Info> infoStream() {
    return controller.stream;
  }

  void connect() async {
    stayConnected = true;
    if (socket == null) {
      // only connect if we aren't already connected
      Socket.connect(server, port, timeout: Duration(seconds: 5)).then((sock) {
        retryTimer?.cancel();
        retryInterval = minRetryInterval;
        sock.listen(
          onData,
          onDone: onDone,
          onError: onError,
        );
        socket = sock;
        connstate = ConnState.connecting;
      }).catchError((e) {
        retry();
      });
    } else {
      retryTimer?.cancel();
    }
  }

  void onData(Uint8List data) {
    var lines = utf8.decode(data).trim().split("\n");
    var last = lines.removeLast();
    if (last.startsWith("OK")) {
      // whatever it was succeeded
      switch (connstate) {
        case ConnState.connecting:
          processConnecting(lines);
          break;
        case ConnState.command:
          processCommand(lines);
          break;
        case ConnState.idle:
          processIdle(lines);
          break;
        case ConnState.readstate:
          processState(lines);
          break;
      }
    } else {
      // assume last line was ACK-something - maybe deal with partial data here
      reconnect();
    }
  }

  void onDone() {
    socket = null;
    retry();
  }

  void onError(e) {
    socket = null;
    retry();
  }

  void getServer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    server = prefs.getString('server') ?? "music";
    port = prefs.getInt('port') ?? 6600;
    if (stayConnected) {
      reconnect();
    }
  }

  void setServer(String? server, int? port) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (server != null) {
      await prefs.setString("server", server);
      this.server = server;
    }
    if (port != null) {
      await prefs.setInt("port", port);
      this.port = port;
    }
    if (stayConnected) {
      reconnect();
    }
  }

  // void changeConnection(String? server, int? port) {
  //   disconnect();
  //   if (server != null) {
  //     this.server = server;
  //   }
  //   if (port != null) {
  //     this.port = port;
  //   }
  //   connect();
  // }

  void disconnect() {
    retryTimer?.cancel();
    if (socket != null) {
      socket!.close();
      socket = null;
    }
    stayConnected = false;
  }

  void retry() {
    retryTimer?.cancel();
    if (stayConnected) {
      controller.add(Info(
          connected: false,
          info: "Trying to connect to server \"$server\" on port $port"));
      retryTimer = Timer(Duration(seconds: retryInterval), connect);
      if (retryInterval < maxRetryInterval) {
        retryInterval += retryIncrement;
      }
    }
  }

  void sendCommand(String message) {
    if (socket != null) {
      socket!.write("noidle\n$message\n");
      connstate = ConnState.command;
    }
  }

  void processConnecting(lines) {
    if (lines.length == 0) {
      getStatus();
    } else {
      reconnect();
    }
  }

  void reconnect() {
    disconnect();
    connect();
  }

  void processCommand(List<String> lines) {
    if (lines.length == 1 && lines.first == "OK") {
      goIdle();
    } else {
      reconnect();
    }
  }

  void processIdle(List<String> lines) {
    var changed = false;
    for (var element in lines) {
      var match = RegExp(r"^changed: (.*)$").firstMatch(element);
      if (match != null) {
        var str = match.group(1);
        if (str != null) {
          if (str.split(" ").any((element) => element == "player")) {
            changed = true;
          }
        }
      }
    }
    if (changed) {
      getStatus();
    } else {
      // it reported a change in idle mode but nothing changed? Ignore? Assume it never happens?
      goIdle();
    }
  }

  void processState(List<String> lines) {
    var info = Info(connected: true); // final info to be sent to the UI
    var md = HashMap<
        String,
        List<
            String>>(); // temporary storage of interesting metadata before processing
    var pattern = RegExp(r'^([^:]+): (.*)$');
    for (var line in lines) {
      var match = pattern.firstMatch(line);
      if (match != null && match.groupCount == 2) {
        var key = (match.group(1) ?? "").toLowerCase();
        var value = match.group(2);
        switch (key) {
          case "repeat":
            info.repeat = value == "1";
            break;
          case "random":
            info.random = value == "1";
            break;
          case "single":
            info.single = value == "single";
            break;
          case "state":
            switch (value) {
              case "play":
                info.state = PlayState.playing;
                break;
              case "pause":
                info.state = PlayState.paused;
                break;
              default:
                info.state = PlayState.stopped;
                break;
            }
            break;
          case "duration":
            info.duration = double.parse(value ?? "0");
            break;
          case "elapsed":
            info.elapsed = double.parse(value ?? "0");
            break;
          case "title":
            info.info = value ?? "?";
            break;
          case "album":
          case "artist":
          case "albumartist":
          case "composer":
          case "performer":
            md.putIfAbsent(key, () => []).add(value ?? "?");
            break;
        }
      }
    }
    // check various metadata scenarios, but only if state isn't stopped
    // for classical sometimes the artist tag contains the composer and
    // sometimes the performer; let's handle those situations as sensibly as
    // possible
    // delete artist if the same as composer or performer
    if (listEquals(md["artist"], md["composer"]) ||
        listEquals(md["artist"], md["performer"])) {
      md.remove("artist");
    }
    // delete albumartist if the same as any other artisty thing
    if (listEquals(md["albumartist"], md["performer"]) ||
        listEquals(md["albumartist"], md["artist"]) ||
        listEquals(md["albumartist"], md["composer"])) {
      md.remove("albumartist");
    }
    // the addAll methods handle nulls and empty lists as no-ops, the clever logic is the deletion and renaming above
    info.addAll(InfoType.composer, md["composer"]);
    info.addAll(InfoType.performer, md["artist"]);
    info.addAll(InfoType.performer, md["performer"]);
    info.addAll(InfoType.performer, md["albumartist"]);
    info.addAll(InfoType.album, md["album"]);
    controller.add(info);
    goIdle();
  }

  void goIdle() {
    sendCommand("idle player");
    connstate = ConnState.idle;
  }

  void getStatus() {
    sendCommand("command_list_begin\nstatus\ncurrentsong\ncommand_list_end");
    connstate = ConnState.readstate;
  }
}
