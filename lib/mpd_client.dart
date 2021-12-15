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
  var retryInterval = minRetryInterval;
  String server;
  int port;
  Socket? socket;
  ConnState connstate = ConnState.connecting;
  bool stayConnected = false; // whether to reconnect on failure/disconnect
  late StreamController<Info> controller;
  var utf8 = Utf8Codec(allowMalformed: true);

  MPDClient([this.server = "music", this.port = 6600]) {
    print("created mpd");
    controller = StreamController<Info>(
        onListen: connect,
        onPause: disconnect,
        onResume: connect,
        onCancel: disconnect);
  }

  Stream<Info> infoStream() {
    return controller.stream;
  }

  void connect() async {
    stayConnected = true;
    if (socket == null) {
      // only connect if we aren't already connected
      print("Destination Address: $server:$port");
      Socket.connect(server, port, timeout: Duration(seconds: 5)).then((sock) {
        print("Connected to ${sock.remoteAddress.address}:${sock.remotePort}");
        retryInterval = minRetryInterval;
        sock.listen(
          onData,
          onDone: onDone,
          onError: onError,
        );
        socket = sock;
        connstate = ConnState.connecting;
      }).catchError((e) {
        print("Connection error: ${e.toString()}");
        retry();
      });
    } else {
      print("Already connected");
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
      resetConnection();
    }
  }

  void onDone() {
    print("Connection has terminated.");
    socket = null;
    retry();
  }

  void onError(e) {
    print("onError: $e");
    socket = null;
    retry();
  }

  void disconnect() {
    print("disconnect");

    if (socket != null) {
      socket!.close();
      socket = null;
    }
    stayConnected = false;
  }

  void retry() {
    if (stayConnected) {
      print("retry after $retryInterval");
      Timer(Duration(seconds: retryInterval), connect);
      if (retryInterval < maxRetryInterval) {
        retryInterval += retryIncrement;
      }
    }
  }

  void sendCommand(String message) {
    if (socket != null) {
      socket!.write("$message\n");
      connstate = ConnState.command;
    }
  }

  void processConnecting(lines) {
    if (lines.length == 0) {
      print("Connected, request status");
      getStatus();
    } else {
      resetConnection();
    }
  }

  void resetConnection() {
    print("Resetting connection");
    // TODO: implement reconnect retry logic
  }

  void processCommand(List<String> lines) {
    print("onCommand, ${lines.length} lines");
    if (lines.length == 1 && lines.first == "OK") {
      goIdle();
    } else {
      resetConnection();
    }
  }

  void processIdle(List<String> lines) {
    print("onIdle, ${lines.length} lines");
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
    print("onState, ${lines.length} lines");
    var info = Info(); // final info to be sent to the UI
    var metadata = HashMap<String,
        String>(); // temporary storage of interesting metadata before processing
    var pattern = RegExp(r'^([^:]+): (.*)$');
    for (var line in lines) {
      //print(line);
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
            info.duration = (double.parse(value ?? "0") * 1000).round();
            break;
          case "elapsed":
            info.elapsed = (double.parse(value ?? "0") * 1000).round();
            break;
          case "title":
            info.info = value ?? "?";
            break;
          case "album":
          case "artist":
          case "albumartist":
          case "composer":
          case "performer":
            metadata[key] = value ?? "?";
            break;
        }
      }
    }
    // check various metadata scenarios
    // for classical sometimes the artist tag contains the composer and
    // sometimes the performer; let's handle those situations as sensibly as
    // possible
    if (metadata.containsKey("composer")) {
      if (metadata["composer"] == metadata["artist"]) {
        // only show it once, as a composer tag
        info.subInfos
            .add(SubInfo(InfoType.composer, metadata["composer"] ?? ""));
      } else {
        // otherwise show them separately
        info.subInfos
            .add(SubInfo(InfoType.composer, metadata["composer"] ?? ""));
        // but only show the artist if it actually exists
        if (metadata.containsKey("artist")) {
          info.subInfos
              .add(SubInfo(InfoType.performer, metadata["artist"] ?? ""));
        }
      }
    } else {
      // no composer, show just the artist
      if (metadata.containsKey("artist")) {
        info.subInfos
            .add(SubInfo(InfoType.performer, metadata["artist"] ?? ""));
      }
    }
    if (metadata.containsKey("performer")) {
      info.subInfos
          .add(SubInfo(InfoType.performer, metadata["performer"] ?? "?"));
    } else if (metadata.containsKey("albumartist") &&
        metadata["albumartist"] != metadata["artist"]) {
      info.subInfos
          .add(SubInfo(InfoType.performer, metadata["albumartist"] ?? "?"));
    }
    if (metadata.containsKey("album")) {
      info.subInfos.add(SubInfo(InfoType.album, metadata["album"] ?? "?"));
    }
    controller.add(info);
    print("Info: $info");
    print("Metadata: $metadata");
    goIdle();
  }

  void goIdle() {
    print("goIdle");
    sendCommand("idle player");
    connstate = ConnState.idle;
  }

  void getStatus() {
    print("getStatus");
    sendCommand("command_list_begin\nstatus\ncurrentsong\ncommand_list_end");
    connstate = ConnState.readstate;
  }
}
