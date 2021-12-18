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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:wakelock/wakelock.dart';
import 'data_classes.dart';
import 'mpd_client.dart';
import 'title_text.dart';
import 'subinfo.dart';
import 'about.dart';

class InfoState {
  Info info = Info();
  double virtualElapsed = 0;
  var sliderUpdateEnabled = true;
  double currentTime = 0;
}

class InfoWidget extends StatefulWidget {
  InfoWidget({Key? key, required this.mpd, required this.title})
      : super(key: key);

  final MPDClient mpd;
  final String title;

  @override
  State<InfoWidget> createState() => _InfoWidgetState();
}

class _InfoWidgetState extends State<InfoWidget> with WidgetsBindingObserver {
  var _state = InfoState();
  late Stream<Info> infoStream;
  StreamSubscription<Info>? subscription;
  int currentScroll = 0;
  int scrollDirection = 1;
  Timer? ticker;

  // used by the dialog to change the MPD server
  String? mpdServer;
  int? mpdPort;

  _InfoWidgetState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
    okGo();
  }

  @override
  void dispose() {
    stopThat();
    WidgetsBinding.instance?.removeObserver(this);
    subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      stopThat();
    }
    if (state == AppLifecycleState.resumed) {
      okGo();
    }
    print('AppLifecycleState state:  $state');
  }

  void okGo() {
    print("okGo");
    infoStream = widget.mpd.infoStream();
    startListening();
    ticker = Timer.periodic(const Duration(seconds: 1), tickScroll);
  }

  void stopThat() {
    ticker?.cancel();
    ticker = null;
    stopListening();
    print("stopThat");
  }

  @override
  Widget build(BuildContext context) {
    var actions = <Widget>[
      IconButton(
          onPressed: _state.info.state == PlayState.stopped
              ? null
              : () => widget.mpd.sendCommand("previous"),
          icon: const Icon(Icons.skip_previous),
          tooltip: 'Previous'),
      IconButton(
          onPressed: () {
            switch (_state.info.state) {
              case PlayState.stopped:
                widget.mpd.sendCommand("play");
                break;
              case PlayState.paused:
                widget.mpd.sendCommand("pause 0");
                break;
              case PlayState.playing:
                widget.mpd.sendCommand("pause 1");
            }
          },
          icon: _state.info.state == PlayState.playing
              ? Icon(Icons.pause)
              : Icon(Icons.play_arrow),
          tooltip: 'Album'),
      IconButton(
          onPressed: _state.info.state == PlayState.stopped
              ? null
              : () => widget.mpd.sendCommand("next"),
          icon: const Icon(Icons.skip_next),
          tooltip: 'Pause'),
      VerticalDivider(),
      Consumer<PageState>(
        builder: (context, pageState, child) => PopupMenuButton<String>(
          icon: const Icon(Icons.text_format),
          itemBuilder: (context) {
            return pageState
                .themeNames()
                .map((name) => CheckedPopupMenuItem(
                      child: Text(name),
                      value: name,
                      checked: name == pageState.themeName,
                    ))
                .toList();
          },
          onSelected: (s) {
            pageState.setTheme(s);
          },
        ),
      ),
      IconButton(
          onPressed: () {
            _displayTextInputDialog(context);
          },
          icon: const Icon(Icons.settings_ethernet),
          tooltip: 'Set MPD Server'),
      IconButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AboutPage()),
          );
        },
        icon: const Icon(Icons.info),
      ),
    ]; //.map((w) => Transform.scale(scale: 1.5, child: w)).toList();
    var bar = AppBar(
      title: Row(
        children: [
          Expanded(
            child: Slider(
                onChangeStart: (startVal) {
                  _state.sliderUpdateEnabled = false;
                  _state.virtualElapsed = startVal;
                },
                onChanged: (val) {
                  setState(() {
                    if (val <= _state.info.duration) {
                      _state.virtualElapsed = val;
                    }
                  });
                },
                onChangeEnd: (endVal) {
                  // sanity check in case the track changed during drag
                  _state.virtualElapsed = endVal <= _state.info.duration
                      ? endVal
                      : _state.info.duration - 0.1;
                  _state.sliderUpdateEnabled = true;
                  widget.mpd.sendCommand("seekcur ${_state.virtualElapsed}");
                },
                value: _state.virtualElapsed,
                max: _state.info.duration,
              ),
          ),
        ],
      ),
      actions: actions,
    );
    return Scaffold(
      appBar: bar,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Container(
            child: TitleText(state: _state.info, context: context),
          ),
          Expanded(
            child:
                SubInfoList(context: context, subInfos: _state.info.subInfos),
          ),
        ],
      ),
    );
  }

  void tickScroll(Timer timer) async {
    if (_state.sliderUpdateEnabled && _state.info.state == PlayState.playing) {
      setState(() {
        // always update the current time, we use it whether paused or playing
        _state.currentTime =
            DateTime.now().millisecondsSinceEpoch.toDouble() / 1000;
        // compute the actual elapsed time based on the elapsed value in the info
        // plus the time difference between when the info was created and now
        final elapsedOffset = _state.currentTime - _state.info.timestamp;
        final targetElapsed = _state.info.elapsed + elapsedOffset;
        // sanity check in case track changed
        if (targetElapsed <= _state.info.duration) {
          _state.virtualElapsed = _state.info.elapsed + elapsedOffset;
        }
      });
    }
    if (_state.info.subInfos.isNotEmpty) {
      final wantedScroll = (_state.virtualElapsed ~/ 5)
          .remainder(_state.info.subInfos.length);
      if (wantedScroll != currentScroll) {
        currentScroll = wantedScroll;
        scrollTo(currentScroll);
      }
    }
  }

  void scrollTo(int pos) async {
    final cntxt = _state.info.subInfos[pos].key.currentContext;
    if (cntxt != null) {
      Scrollable.ensureVisible(
        cntxt,
        duration: Duration(seconds: 1),
        curve: Curves.easeInOut,
      );
    }
  }

  void startListening() async {
    if (subscription == null) {
      subscription = infoStream.listen((info) {
        setState(() {
          if (info.state == PlayState.playing) {
            Wakelock.enable();
          } else {
            Wakelock.disable();
          }
          _state.info = info;
          if (_state.sliderUpdateEnabled) {
            _state.virtualElapsed = _state.info.elapsed;
          }
        });
        scrollTo(0);
      });
    } else {
      if (subscription?.isPaused ?? false) {
        subscription?.resume();
      }
    }
  }

  void stopListening() {
    subscription?.pause();
  }

  TextEditingValue ipPort(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      // we have to allow blanks, otherwise we can't delete the last digit
      return newValue;
    }
    final port = int.tryParse(newValue.text);
    if (port == null || port <= 0 || port >= 65536) {
      return oldValue;
    }
    return newValue;
  }

  Future<void> _displayTextInputDialog(BuildContext context) async {
    var oneLine = FilteringTextInputFormatter.singleLineFormatter;
    var portOnly = TextInputFormatter.withFunction(ipPort);
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('MPD Server'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    onChanged: (value) {
                      print("server: $value");
                      mpdServer = value;
                    },
                    inputFormatters: [oneLine],
                    controller: TextEditingController(text: widget.mpd.server),
                    decoration: InputDecoration(hintText: "Name or IP address"),
                  ),
                  TextField(
                    onChanged: (value) {
                      print("port: $value");
                      mpdPort = int.parse(
                          value); // no need to catch exception, ipPort() has validated it already
                    },
                    inputFormatters: [portOnly],
                    controller:
                        TextEditingController(text: widget.mpd.port.toString()),
                    decoration:
                        InputDecoration(hintText: "Port number (default 6600)"),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Connect'),
                onPressed: () {
                  widget.mpd.changeConnection(mpdServer, mpdPort);
                  Navigator.pop(context);
                },
              ),
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        });
  }
}
