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
import 'data_classes.dart';
import 'mpd_client.dart';

class PageState {
  Info info = Info();
  String themeName = "Manuscript";

  PageState();
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  static const double _titleSize = 72;
  static const double _infoSize = 56;

  static const themes = {
    "Plain": {},
    "Manuscript": {
      "font": "Baskerville",
      "bgcolour": Colors.white,
      "titlecolour": Colors.black,
      "infocolour": Colors.black,
    },
    "Cyberpunk": {
      "font": "Swerve",
      "bgcolour": Colors.black,
      "titlecolor": Colors.pink,
      "infocolor": Colors.blue,
    },
  };

  var _state = PageState();
  var mpd = MPDClient();
  late Stream<Info> infoStream;
  StreamSubscription<Info>? subscription = null;

  _MainPageState() {
    infoStream = mpd.infoStream();
  }

  @override
  void initState() {
    super.initState();
    startListening();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var themeMap = themes[_state.themeName];
    var textTheme = Theme.of(context).textTheme.copyWith(
          headline1: TextStyle(
            fontFamily: themeMap?["font"],
            fontSize: _titleSize,
            color: themeMap?["titlecolour"],
          ),
          headline2: TextStyle(
            fontFamily: themeMap?["font"],
            fontSize: _infoSize,
            color: themeMap?["infocolour"],
          ),
        );
    var theme = Theme.of(context).copyWith(
      textTheme: textTheme,
      backgroundColor: themeMap?["bgcolour"],
    );
    var bar = AppBar(
      title: Text(widget.title),
      actions: <Widget>[
        const IconButton(
            onPressed: null,
            icon: const Icon(Icons.skip_previous),
            tooltip: 'Previous'),
        const IconButton(
            onPressed: null, icon: const Icon(Icons.pause), tooltip: 'Album'),
        const IconButton(
            onPressed: null,
            icon: const Icon(Icons.skip_next),
            tooltip: 'Pause'),
        const IconButton(
            onPressed: null,
            icon: const Icon(Icons.sync_problem),
            tooltip: 'Disconnected'),
        const IconButton(
            onPressed: null,
            icon: const Icon(Icons.block_sharp),
            tooltip: 'Disconnected'),
      ].map((w) => Transform.scale(scale: 1.5, child: w)).toList(),
    );
    return Scaffold(
      appBar: bar,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Container(
            child: titleWidget(theme),
          ),
          Expanded(
            child: subInfoList(theme),
          ),
        ],
      ),
    );
  }

  Widget titleWidget(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        _state.info.info ?? "-",
        textAlign: TextAlign.center,
        softWrap: true,
        maxLines: 4,
        overflow: TextOverflow.fade,
        style: theme.textTheme.headline1,
      ),
    );
  }

  Widget subInfoList(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children:
              _state.info.subInfos.map((i) => subInfoRow(theme, i)).toList(),
        ),
      ),
    );
  }

  IconData infoTypeToIcon(InfoType type) {
    switch (type) {
      case InfoType.album:
        return Icons.album;
      case InfoType.composer:
        return Icons.edit;
      case InfoType.performer:
        return Icons.piano;
      default:
        return Icons.device_unknown;
    }
  }

  Widget subInfoRow(ThemeData theme, SubInfo i) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: Icon(infoTypeToIcon(i.type), size: _infoSize),
        ),
        Flexible(
          child: Text(
            i.text,
            textAlign: TextAlign.left,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            maxLines: 3,
            style: theme.textTheme.headline2,
          ),
        ),
      ],
    );
  }

  void startListening() async {
    if (subscription == null) {
      subscription = infoStream.listen((info) {
        setState(() {
          _state.info = info;
        });
      });
    } else {
      if (subscription?.isPaused ?? false) {
        subscription?.resume();
      } else {
        subscription?.pause();
      }
    }
  }

  void stopListening() {
    subscription?.cancel();
    subscription = null;
  }
}
