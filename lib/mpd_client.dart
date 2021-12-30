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
  List<String> lineBuffer = [];
  bool partialLine =
      false; // did the last chunk of data received from MPD end without a newline?

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

  void notifyDisconnected([String? msg]) {
    controller.add(Info(
      connected: false,
      info: msg,
    ));
  }

  void connect() {
    if (kDebugMode) {
      print("connect");
    }
    stayConnected = true;
    connectSocket();
  }

  void disconnect() {
    if (kDebugMode) {
      print("disconnect");
    }
    stayConnected = false;
    disconnectSocket();
  }

  Future<void> connectSocket() async {
    if (kDebugMode) {
      print("connectSocket");
    }
    retryTimer?.cancel();
    await loadServerPrefs();
    if (socket == null) {
      // only connect if we aren't already connected
      if (kDebugMode) {
        print("connectSocket: connecting");
      }
      Socket.connect(server, port, timeout: const Duration(seconds: 5))
          .then((sock) {
        if (kDebugMode) {
          print("connectSocket: connected");
        }
        retryInterval = minRetryInterval;
        sock.listen(
          onData,
          onDone: onDone,
          onError: onError,
          cancelOnError:
              true, // we want it to be safe to destroy the socket and re-connect after any error
        );
        socket = sock;
        connstate = ConnState.connecting;
      }).catchError((e) {
        if (kDebugMode) {
          print("connectSocket: caught error");
        }
        notifyDisconnected();
        // if we need to retry here there is no valid socket so we can re-call this function
        retry(connectSocket);
      });
    }
  }

  Future<void> disconnectSocket() async {
    if (kDebugMode) {
      print("disconnectSocket");
    }
    retryTimer?.cancel();
    if (kDebugMode) {
      print("disconnectSocket: flushing");
    }
    await socket?.flush();
    if (kDebugMode) {
      print("disconnectSocket: destroying");
    }
    socket?.destroy(); // this will trigger onDone()
    if (kDebugMode) {
      print("disconnectSocket: destroyed");
    }
  }

  void onData(Uint8List data) {
    final dataStr = utf8.decode(data);
    final newIsPartial = !dataStr.endsWith('\n');
    final newLines = dataStr.trim().split("\n");
    if (kDebugMode) {
      print(
          "got ${newLines.length} new, partial $newIsPartial");
    }
    if (partialLine && lineBuffer.isNotEmpty) {
      // the previous data was partial, so pop it off and prepend it to the new first line
      newLines[0] = lineBuffer.removeLast() + newLines[0];
      if (kDebugMode) {
        print("previous was partial, adjusted to ${newLines[0]}");
      }
    }
    lineBuffer.addAll(newLines);
    partialLine = newIsPartial;
    // only process the line buffer if it is *not* partial *and* it ends with OK or ACK
    if (!partialLine &&
        (lineBuffer.last.startsWith("OK") ||
            lineBuffer.last.startsWith("ACK"))) {
      switch (connstate) {
        case ConnState.connecting:
          processConnecting(lineBuffer);
          break;
        case ConnState.command:
        case ConnState.readoutput:
          processMPDOutput(lineBuffer);
          break;
      }
      lineBuffer.clear(); // we processed it, clear the buffer
    } else {
      if (kDebugMode) {
        print("partial new data, not processing yet: $lineBuffer");
      }
    }
  }

  void onDone() {
    if (kDebugMode) {
      print("onDone");
    }
    notifyDisconnected();
    socket?.destroy(); // destroy it to ensure TCP stuff is cleaned up
    socket = null;
    if (stayConnected) {
      connectSocket();
    }
  }

  void onError(e) {
    if (kDebugMode) {
      print("onError: $e");
    }
    notifyDisconnected();
    // the subscription is set to cancel on error, so onDone will not be called
    if (kDebugMode) {
      print("onError: destroying socket");
    }
    socket?.destroy();
    socket = null;
    if (stayConnected) {
      retry(() async {
        if (kDebugMode) {
          print("retry after error");
          connectSocket();
        }
      });
    }
  }

  Future<void> loadServerPrefs() async {
    if (kDebugMode) {
      print("loadServerPrefs");
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    server = prefs.getString('server') ?? "music";
    port = prefs.getInt('port') ?? 6600;
    if (kDebugMode) {
      print("loadServerPrefs: found $server:$port");
    }
  }

  Future<void> setServer(String? server, int? port) async {
    if (kDebugMode) {
      print("setServer");
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (server != null) {
      await prefs.setString("server", server);
      this.server = server;
    }
    if (port != null) {
      await prefs.setInt("port", port);
      this.port = port;
    }
    if (kDebugMode) {
      print("setServer: saved");
    }
    // if currently connected, this will trigger onDone(), which will call
    // connect() (since stayConnected will still be true), using the settings we
    // just saved; if not connected then the next retry will pick up the new
    // settings
    socket?.destroy();
  }

  Future<void> retry(Future<void> Function() retryAction) async {
    if (kDebugMode) {
      print("retry: retry in ${retryInterval}s");
    }
    retryTimer?.cancel(); // cancel the old one, if any
    retryTimer = Timer(Duration(seconds: retryInterval), retryAction);
    if (retryInterval < maxRetryInterval) {
      retryInterval += retryIncrement;
    }
  }

  void sendCommand(String message) {
    if (kDebugMode) {
      print("sendCommand");
    }
    if (socket != null) {
      if (kDebugMode) {
        print("send command: $message");
      }
      socket!.write("noidle\n$message\n");
      connstate = ConnState.command;
    }
  }

  void processConnecting(List<String> lines) {
    if (kDebugMode) {
      print("processConnecting");
    }
    final mpdVersionPattern = RegExp(r'^OK MPD [.0-9]+$');
    if (lines.length >= 1 && mpdVersionPattern.hasMatch(lines[0])) {
      print("processConnecting: getstatus");
      getStatus();
    } else {
      if (kDebugMode) {
        print("processConnecting: not an MPD server: ${lines}");
      }
      notifyDisconnected("Not an MPD player");
    }
  }

  void processCommand(List<String> lines) {
    if (kDebugMode) {
      print("processCommand");
    }
    if (lines.length == 1 && lines.first == "OK") {
      if (kDebugMode) {
        print("processCommand: OK");
      }
      goIdle();
    } else {
      if (kDebugMode) {
        print("processCommand: not OK");
      }
      // in future perhaps perform some UI action to indicate a failure but for now just suck it up
      goIdle();
    }
  }

  void processMPDOutput(List<String> lines) {
    if (kDebugMode) {
      print("processMPDOutput");
    }
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
    if (kDebugMode) {
      print("processMPDOutput: reading lines in state: $connstate");
    }
    for (var line in lines) {
      if (error) {
        if (kDebugMode) {
          print("processMPDOutput: skipping because of error");
        }
        break; // ignore the rest of the lines
      }
      //print("processMPDOutput: processing line: $line");
      if (okPattern.hasMatch(line)) {
        if (kDebugMode) {
          print("processMPDOutput: OK detected");
        }
        // we found an "OK", signalling the end of a section of the response
        // if we processed more than one line on this pass, assume it was status output and process it
        if (sectionLineCount > 1) {
          if (kDebugMode) {
            print("processMPDOutput: processing metadata");
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
          if (md.containsKey("performer")) {
            // if performers exist then assume the artist is the composer
            info.addAll(InfoType.composer, md["artist"]);
          } else {
            // otherwise assume it's a regular artist/performer
            info.addAll(InfoType.performer, md["artist"]);
          }
          info.addAll(InfoType.performer, md["performer"]);
          info.addAll(InfoType.performer, md["albumartist"]);
          info.addAll(InfoType.album, md["album"]);
          info.addAll(InfoType.station, md["name"]);
          var techData = <String>[];
          if (info.duration > 0) {
            techData.add(info.durationToString());
          }
          if (info.fileType != null) {
            techData.add(info.fileType!);
          }
          if (md.containsKey("audio")) {
            techData.add(md["audio"]?.join("") ?? "");
          }
          if (info.song > 0 && info.playlistlength > 0) {
            techData.add("(${info.song}/${info.playlistlength})");
          }
          if (techData.isNotEmpty) {
            info.subInfos.add(SubInfo(InfoType.technical, techData.join(" ")));
          }
          if (kDebugMode) {
            print(
                "processMPDOutput: sending ${info.info} sic ${info.subInfos.length}");
          }
          controller.add(info);
        }
        info = Info(
            connected:
                true); // create a new info as we continue to process input
        md.clear();
        sectionLineCount = 0;
      } else if (ackPattern.hasMatch(line)) {
        if (kDebugMode) {
          print("processMPDOutput: error detected: $line");
        }
        error = true;
      } else {
        ++sectionLineCount;
        var match = dataPattern.firstMatch(line);
        if (match != null && match.groupCount == 2) {
          var key = (match.group(1) ?? "").toLowerCase();
          var value = match.group(2);
          switch (key) {
            case "changed":
              if (kDebugMode) {
                print("processMPDOutput: change detected");
              }
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
            case "song":
              info.song = int.parse(value ?? "0");
              break;
            case "playlistlength":
              info.playlistlength = int.parse(value ?? "0");
              break;
            case "title":
              info.info = value ?? "?";
              break;
            case "file":
              info.setFiletypeFromPath(value);
              break;
            case "album":
            case "artist":
            case "albumartist":
            case "composer":
            case "performer":
            case "name": // name of a radio station
            case "audio": // audio file details
              md.putIfAbsent(key, () => []).add(value ?? "?");
              break;
          }
        }
      }
    }
    if (error) {
      if (kDebugMode) {
        print("processMPDOutput: found error");
      }
      // in future perhaps perform some UI action to indicate a failure but for now just suck it up
      goIdle();
    } else if (changed) {
      if (kDebugMode) {
        print("processMPDOutput: changed, trying get status");
      }
      getStatus();
    } else {
      if (kDebugMode) {
        print("processMPDOutput: go idle");
      }
      goIdle();
    }
  }

  void goIdle() {
    if (kDebugMode) {
      print("goIdle");
    }
    sendCommand("idle player database playlist");
    connstate = ConnState.readoutput;
  }

  void getStatus() {
    if (kDebugMode) {
      print("getStatus");
    }
    sendCommand("command_list_begin\nstatus\ncurrentsong\ncommand_list_end");
    connstate = ConnState.readoutput;
  }
}
