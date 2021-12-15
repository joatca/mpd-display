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
import 'package:mpd_display/main_page.dart';
import 'data_classes.dart';
import 'mpd_client.dart';
import 'title_text.dart';
import 'subinfo.dart';
import 'about.dart';

class InfoWidget extends StatefulWidget {
  InfoWidget(
      {Key? key,
      required this.mpd,
      required this.setThemeCallback,
      required this.title})
      : super(key: key);

  final MPDClient mpd;
  final void Function(String a) setThemeCallback;
  final String title;

  @override
  State<InfoWidget> createState() => _InfoWidgetState();
}

class _InfoWidgetState extends State<InfoWidget> with WidgetsBindingObserver {
  var _state = Info();
  late Stream<Info> infoStream;
  StreamSubscription<Info>? subscription;
  int currentScroll = 0;
  int scrollDirection = 1;
  Timer? ticker;

  _InfoWidgetState() {}

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
    ticker = Timer.periodic(Duration(seconds: 5), tickScroll);
  }

  void stopThat() {
    ticker?.cancel();
    ticker = null;
    stopListening();
    print("stopThat");
  }

  @override
  Widget build(BuildContext context) {
    final mainPageData = MainPageData.of(context);
    var actions = <Widget>[
      IconButton(
          onPressed: _state.state == PlayState.stopped
              ? null
              : () => widget.mpd.sendCommand("previous"),
          icon: const Icon(Icons.skip_previous),
          tooltip: 'Previous'),
      IconButton(
          onPressed: () {
            switch (_state.state) {
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
          icon: _state.state == PlayState.playing
              ? Icon(Icons.pause)
              : Icon(Icons.play_arrow),
          tooltip: 'Album'),
      IconButton(
          onPressed: _state.state == PlayState.stopped
              ? null
              : () => widget.mpd.sendCommand("next"),
          icon: const Icon(Icons.skip_next),
          tooltip: 'Pause'),
      VerticalDivider(),
      PopupMenuButton<String>(
        icon: const Icon(Icons.text_format),
        itemBuilder: (context) {
          return mainPageData.themeNames
              .map((name) => CheckedPopupMenuItem(
                    child: Text(name),
                    value: name,
                    checked: name == mainPageData.theme,
                  ))
              .toList();
        },
        onSelected: (s) {
          widget.setThemeCallback(s);
        },
      ),
      IconButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AboutPage()),
          );
        },
        icon: const Icon(Icons.settings),
      ),
    ]; //.map((w) => Transform.scale(scale: 1.5, child: w)).toList();
    var bar = AppBar(
      title: Text(widget.title),
      actions: actions,
    );
    return Scaffold(
      appBar: bar,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Container(
            child: TitleText(state: _state, context: context),
          ),
          Expanded(
            child: SubInfoList(context: context, subInfos: _state.subInfos),
          ),
        ],
      ),
    );
  }

  void tickScroll(Timer timer) async {
    if (_state.subInfos.isNotEmpty) {
      currentScroll += 1;
      if (currentScroll >= _state.subInfos.length) {
        currentScroll = 0;
      }
      scrollTo(currentScroll);
    }
  }

  void scrollTo(int pos) async {
    final cntxt = _state.subInfos[pos].key.currentContext;
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
          _state = info;
        });
        currentScroll = -1;
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
}
