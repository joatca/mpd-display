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
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data_classes.dart';

/* this data class connects to an MPD server and sends play state data on the supplied stream */

typedef Lines = List<String>;
typedef Response = HashMap<String, List<String>>;

enum ConnState {
  awaitConnection, // we have just connected and we're waiting for a response
  awaitChange, // we sent the idle command and are waiting for a response
  awaitStatus, // we sent commands to fetch the state and are waiting for a response
  awaitCommandResult, // we sent a command (like play) and are waiting for a response
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
  ConnState connstate = ConnState.awaitConnection;
  var commandQueue = List<String>.empty(growable: true);
  bool stayConnected = false; // whether to reconnect on failure/disconnect
  late StreamController<Info> infoController;
  final utf8 = const Utf8Codec(allowMalformed: true);
  Lines lineBuffer = [];
  bool partialLineRemaining =
      false; // did the last chunk of data received from MPD end without a newline?
  String prevPartialLine = "";
  var responseBuffer = Response();

  MPDClient() {
    infoController = StreamController<Info>(
        onListen: connect,
        onPause: disconnect,
        onResume: connect,
        onCancel: disconnect);
  }

  Stream<Info> infoStream() {
    return infoController.stream;
  }

  void notifyDisconnected([String? msg]) {
    infoController.add(Info(
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
          accumulateData,
          onDone: onDone,
          onError: onError,
          cancelOnError:
              true, // we want it to be safe to destroy the socket and re-connect after any error
        );
        socket = sock;
        connstate = ConnState.awaitConnection;
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

  // accept blocks of data from the socket, split to lines, accumulate key-value
  // lines into a hashmap buffer and whenever we hit an OK, pass the buffer to
  // be interpreted then discarded, or if ACK discard without action
  void accumulateData(Uint8List data) {
    final dataPattern = RegExp(r'^([^:]+): (.*)$');
    final okPattern = RegExp(r'^OK');
    final ackPattern = RegExp(r'^ACK');
    final dataStr = utf8.decode(data);
    final newIsPartial = !dataStr.endsWith('\n');
    final newLines = dataStr.trim().split("\n");
    if (kDebugMode) {
      if (dataStr.length < 60) {
        print("dataStr = \"$dataStr\"");
      }
      if (newLines.length <= 2) {
        print("got $newLines, partial $newIsPartial");
      } else {
        print("got ${newLines.length} new, partial $newIsPartial");
      }
    }
    // append the previous partial line (might be empty) to the first new line
    newLines[0] = prevPartialLine + newLines[0];
    // if the last line was partial, pop it off and save it
    prevPartialLine = newIsPartial ? newLines.removeLast() : "";
    if (kDebugMode) {
      print("accumulateData: prevPartialLine = \"$prevPartialLine\"");
    }
    // accumulate the new lines into the response buffer
    for (final line in newLines) {
      if (okPattern.hasMatch(line)) {
        // we have a complete response, process it
        if (kDebugMode) {
          print("accumulateData: OK found: \"$line\"");
        }
        switch (connstate) {
          case ConnState.awaitConnection:
            processConnecting(line);
            break;
          case ConnState.awaitChange:
            processChanged(responseBuffer);
            break;
          case ConnState.awaitCommandResult:
            processCommand();
            break;
          case ConnState.awaitStatus:
            processStatusResponse(responseBuffer);
            break;
        }
        responseBuffer.clear();
        // we don't initiate any other action here because it's assumed one of the above functions did that
      } else if (ackPattern.hasMatch(line)) {
        // error so we can't use the previous output; basically do nothing at the moment
        if (kDebugMode) {
          //print("accumulateData: error found: \"$line\"");
        }
        responseBuffer.clear();
        idleAwaitChanges();
      } else {
        // must be a data line, add it to the response buffer hashmap
        if (kDebugMode) {
          //print("accumulateData: regular line found: \"$line\"");
        }
        var match = dataPattern.firstMatch(line);
        if (match != null && match.groupCount == 2) {
          var key = (match.group(1) ?? "").toLowerCase();
          var value = match.group(2);
          if (kDebugMode) {
            //print("accumulateData: key \"$key\" value \"$value\"");
          }
          responseBuffer.putIfAbsent(key, () => []).add(value ?? "?");
        }
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

  void sendCommand(String command,
      [ConnState newState = ConnState.awaitCommandResult]) {
    if (socket != null) {
      if (kDebugMode) {
        print("sendCommand: $command new state $newState");
      }
      if (connstate == ConnState.awaitChange) {
        // we're waiting for an idle command so queue the requested command then undo the idle
        if (kDebugMode) {
          print("sendCommand: queuing command \"$command\" and sending noidle");
        }
        commandQueue.add(command);
        socket!.write("noidle\n");
        connstate = ConnState.awaitCommandResult;
      } else {
        socket!.write("$command\n");
        connstate = newState;
      }
    }
  }

  void processConnecting(String resultLine) {
    if (kDebugMode) {
      print("processConnecting");
    }
    final mpdVersionPattern = RegExp(r'^OK MPD [.0-9]+$');
    if (mpdVersionPattern.hasMatch(resultLine)) {
      if (kDebugMode) {
        print("processConnecting: getstatus");
      }
      getStatus();
    } else {
      if (kDebugMode) {
        print("processConnecting: not an MPD server: $resultLine");
      }
      notifyDisconnected("Not an MPD server");
    }
  }

  void processCommand() {
    if (kDebugMode) {
      print("processCommand");
    }
    // in future perhaps perform some UI action to indicate a failure but for now just suck it up
    if (commandQueue.isNotEmpty) {
      // usually because we tried to send a command while awaiting a change from
      // idle, so send that command and remain in the same state
      if (kDebugMode) {
        print("processCommand: sending pending command");
      }
      sendCommand(commandQueue.removeLast(), ConnState.awaitCommandResult);
    } else {
      // no pending commands, await further changes
      idleAwaitChanges();
    }
  }

  // MPD notified us that something changed
  void processChanged(Response response) {
    // we don't actually care what changed at the moment, we just update everything
    if (kDebugMode) {
      print("processChanged: \"$response\"");
    }
    // we're never going to have any commands to queue in this state and we must
    // ensure that when we finally hit sendCommand() we're not still in the
    // awaitChange state; as ugly as this is, it's a relatively simple hack
    // compared to the alternatives
    connstate = ConnState.awaitCommandResult;
    getStatus();
  }

  // accepts a key and an anonymous function; if the key exists in the current
  // response and there is at least one value, pass the first value to the
  // function, otherwise do not call
  void consumeKey(String key, void Function(String?) action) {
    if (responseBuffer.containsKey(key)) {
      if (kDebugMode) {
        print("consumeKey: calling function for key \"$key\"");
      }
      try {
        action(responseBuffer[key]!.first);
      } on StateError {
        action(null);
      }
      responseBuffer.remove(key);
    } else {
      if (kDebugMode) {
        print("consumeKey: no value for key \"$key\"");
      }
    }
  }

  void processStatusResponse(Response response) {
    var info = Info(connected: true); // info to be sent to the UI
    if (kDebugMode) {
      print("processStatusResponse: reading lines in state: $connstate");
    }
    consumeKey("repeat", (v) {
      info.repeat = v == "1";
    });
    consumeKey("random", (v) {
      info.random = v == "1";
    });
    consumeKey("consume", (v) {
      info.consume = v == "1";
    });
    consumeKey("single", (v) {
      info.single = v == "1";
    });
    consumeKey("state", (v) {
      switch (v) {
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
    });
    if (info.state != PlayState.stopped) {
      // we only care about this stuff if playing or paused
      consumeKey("duration", (v) {
        info.duration = double.parse(v ?? "0");
      });
      consumeKey("elapsed", (v) {
        info.elapsed = double.parse(v ?? "0");
      });
      consumeKey("song", (v) {
        info.song = int.parse(v ?? "-1");
      });
      consumeKey("playlistlength", (v) {
        info.playlistlength = int.parse(v ?? "0");
      });
      consumeKey("title", (v) {
        info.info = v ?? "?";
      });
      consumeKey("file", (v) {
        info.setFiletypeFromPath(v ?? "");
      });
      cleanResponse(response);
      copyResponseToInfo(response, info);
    }
    if (kDebugMode) {
      print("processStatusResponse: sending to info: $info");
    }
    infoController.add(info);
    idleAwaitChanges();
  }

  void cleanResponse(Response response) {
    // check various metadata scenarios and clean up the response
    // for classical sometimes the artist tag contains the composer and
    // sometimes the performer; let's handle those situations as sensibly as
    // possible
    // delete artist if the same as composer or performer
    if (listEquals(response["artist"], response["composer"]) ||
        listEquals(response["artist"], response["performer"])) {
      response.remove("artist");
    }
    // delete albumartist if the same as any other artisty thing
    if (listEquals(response["albumartist"], response["performer"]) ||
        listEquals(response["albumartist"], response["artist"]) ||
        listEquals(response["albumartist"], response["composer"])) {
      response.remove("albumartist");
    }
  }

  void copyResponseToInfo(Response response, Info info) {
    // the addAll methods handle nulls and empty lists as no-ops, the clever logic is the deletion and renaming above
    info.addAll(InfoType.composer, response["composer"]);
    if (response.containsKey("performer")) {
      // if performers exist then assume the artist is the composer
      info.addAll(InfoType.composer, response["artist"]);
    } else {
      // otherwise assume it's a regular artist/performer
      info.addAll(InfoType.performer, response["artist"]);
    }
    info.addAll(InfoType.performer, response["performer"]);
    info.addAll(InfoType.performer, response["albumartist"]);
    var trackDetails = response.containsKey("track")
        ? " (#${response["track"]?.first ?? "?"})"
        : "";
    info.addAll(InfoType.album, response["album"], trackDetails);
    info.addAll(InfoType.station, response["name"]);
    info.addAll(InfoType.genre, response["genre"]);
    var queueData = <String>[];
    if (info.duration > 0) {
      queueData.add(info.durationToString());
    }
    if (info.song >= 0 && info.playlistlength > 0) {
      if (info.consume) {
        // in consume mode we only show the number of remaining tracks,
        // and it doesn't matter whether we are in random mode or not
        queueData.add("+${info.playlistlength - 1}");
      } else if (!info.random) {
        // otherwise only show playlist position when not random, since in
        // random mode it doesn't make sense
        queueData.add("${info.song + 1}/${info.playlistlength}");
      }
    }
    if (queueData.isNotEmpty) {
      info.subInfos.add(SubInfo(InfoType.queueinfo, queueData.join(" ")));
    }
    if (info.fileType != null && response.containsKey("audio")) {
      info.add(InfoType.technical,
          readableAudioFormat(info.fileType, response["audio"]!.first));
    }
  }

  String readableAudioFormat(String? fileType, String format) {
    final pcmFormat = RegExp(r'^(\d+):(\d+):(\d)$');
    final dsdFormat = RegExp(r'^dsd(\d+):(\d)$');
    var rv = "";

    final pcmMatch = pcmFormat.firstMatch(format);
    if (pcmMatch != null) {
      final sampleRate = double.parse(pcmMatch.group(1) ?? "0") / 1000.0;
      rv += "${pcmMatch.group(2)}/${sampleRate}";
      if (fileType != null) {
        rv += " ${fileType.toUpperCase()}";
      }
    } else {
      final dsdMatch = dsdFormat.firstMatch(format);
      if (dsdMatch != null) {
        rv += (dsdMatch.group(1) ?? "").toUpperCase();
      } else {
        rv += "$format ${(fileType ?? "").toUpperCase()}";
      }
    }
    return rv;
  }

  void idleAwaitChanges() {
    if (kDebugMode) {
      print("idleAwaitChanges");
    }
    sendCommand(
        "idle player database playlist options message", ConnState.awaitChange);
  }

  void getStatus() {
    if (kDebugMode) {
      print("getStatus");
    }
    const commands =
        "command_list_begin\nstatus\ncurrentsong\nreadmessages\ncommand_list_end";
    sendCommand(commands, ConnState.awaitStatus);
  }
}
