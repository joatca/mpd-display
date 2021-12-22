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
  //idle, // we sent the idle command and are waiting for a response
  readoutput, // we sent commands to fetch the state and are waiting for a response
  command, // we sent a command (like play) and are waiting for a response
}

class MPDClient {
  static const minRetryInterval = 1;
  static const maxRetryInterval = 5;
  static const retryIncrement = 1;
  Timer? retryTimer;
  var retryInterval = minRetryInterval;
  String server = "";
  int port = 6600;
  Socket? socket;
  ConnState connstate = ConnState.connecting;
  bool stayConnected = false; // whether to reconnect on failure/disconnect
  late StreamController<Info> controller;
  final utf8 = const Utf8Codec(allowMalformed: true);

  MPDClient() {
    controller = StreamController<Info>(
        onListen: connect,
        onPause: disconnect,
        onResume: connect,
        onCancel: disconnect);
  }

  Stream<Info> infoStream() {
    return controller.stream;
  }

  Future<void> connect() async {
    pid("connect");
    await loadServerPrefs();
    stayConnected = true;
    if (socket == null) {
      // only connect if we aren't already connected
      pid("connecting");
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

  Future<void> disconnect() async {
    pid("disconnect");
    retryTimer?.cancel();
    pid("flushing");
    await socket?.flush();
    pid("closing");
    await socket?.close();
    pid("closed");
    socket = null;
    stayConnected = false;
  }

  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }

  void onData(Uint8List data) {
    var lines = utf8.decode(data).trim().split("\n");
    pid("read: $lines");
    switch (connstate) {
      case ConnState.connecting:
        processConnecting(lines);
        break;
      case ConnState.command:
      case ConnState.readoutput:
        processMPDOutput(lines);
        break;
    }
  }

  void onDone() {
    pid("ondone");
    retry();
  }

  void onError(e) {
    pid("onerror: $e");
    socket = null;
    retry();
  }

  Future<void> loadServerPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    server = prefs.getString('server') ?? "music";
    port = prefs.getInt('port') ?? 6600;
    if (stayConnected) {
      await reconnect();
    }
  }

  Future<void> setServer(String? server, int? port) async {
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
      await reconnect();
    }
  }

  Future<void> retry() async {
    retryTimer?.cancel();
    if (stayConnected) {
      controller.add(Info(
        connected: false,
      ));
      await disconnect();
      retryTimer = Timer(Duration(seconds: retryInterval), connect);
      pid("retry in $retryTimer");
      if (retryInterval < maxRetryInterval) {
        retryInterval += retryIncrement;
      }
    }
  }

  void sendCommand(String message) {
    if (socket != null) {
      pid("send command: $message");
      socket!.write("noidle\n$message\n");
      connstate = ConnState.command;
    }
  }

  void processConnecting(lines) {
    if (lines.length == 1 && lines[0].startsWith("OK")) {
      pid("connecting: getstatus");
      getStatus();
    } else {
      pid("connecting: reconnecting");
      reconnect();
    }
  }

  void processCommand(List<String> lines) {
    if (lines.length == 1 && lines.first == "OK") {
      pid("command: goidle");
      goIdle();
    } else {
      pid("command: reconnecting");
      reconnect();
    }
  }

  void pid(String msg) {
    //print("${identityHashCode(this)}: $msg");
  }

  void processMPDOutput(List<String> lines) {
    var error = false;
    var changed = false;
    var info = Info(connected: true); // info to be sent to the UI
    var md = HashMap<
        String,
        List<
            String>>(); // temporary storage of interesting metadata before processing
    final dataPattern = RegExp(r'^([^:]+): (.*)$');
    final okPattern = RegExp(r'^OK');
    final ackPattern = RegExp(r'^ACK');
    var sectionLineCount = 0;
    pid("processing batch, state: $connstate");
    for (var line in lines) {
      if (error) {
        pid("skipping because of error");
        break; // ignore the rest of the lines
      }
      pid("processing line: $line");
      if (okPattern.hasMatch(line)) {
        pid("OK detected");
        // we found an "OK", signalling the end of a section of the response
        // if we processed more than one line on this pass, assume it was status output and process it
        if (sectionLineCount > 1) {
          pid("processing metadata");
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
          info.addAll(InfoType.station, md["name"]);
          if (info.hasData()) {
            pid("state: sending ${info.info} sic ${info.subInfos.length}");
            controller.add(info);
          } else {
            pid("no data to send");
          }
        }
        info = Info(
            connected:
                true); // create a new info as we continue to process input
        md.clear();
        sectionLineCount = 0;
      } else if (ackPattern.hasMatch(line)) {
        pid("error detected: $line");
        error = true;
      } else {
        ++sectionLineCount;
        var match = dataPattern.firstMatch(line);
        if (match != null && match.groupCount == 2) {
          var key = (match.group(1) ?? "").toLowerCase();
          var value = match.group(2);
          switch (key) {
            case "changed":
              pid("change detected");
              changed = true;
              break;
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
            case "name": // name of the radio station
              md.putIfAbsent(key, () => []).add(value ?? "?");
              break;
          }
        }
      }
    }
    if (error) {
      reconnect();
    } else if (changed) {
      getStatus();
    } else {
      goIdle();
    }
  }

  void goIdle() {
    sendCommand("idle player");
    connstate = ConnState.readoutput;
  }

  void getStatus() {
    sendCommand("command_list_begin\nstatus\ncurrentsong\ncommand_list_end");
    connstate = ConnState.readoutput;
  }
}
