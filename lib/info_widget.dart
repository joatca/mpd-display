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

class _InfoWidgetState extends State<InfoWidget> {
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
    infoStream = widget.mpd.infoStream();
    startListening();
    ticker = Timer.periodic(Duration(seconds: 5), tickScroll);
  }

  @override
  void dispose() {
    ticker?.cancel();
    ticker = null;
    stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeNames = ThemeNames.of(context).themeNames;
    var bar = AppBar(
      title: Text(widget.title),
      actions: <Widget>[
        PopupMenuButton<String>(
          icon: const Icon(Icons.text_format),
          itemBuilder: (context) {
            return themeNames
                .map((name) => PopupMenuItem(child: Text(name), value: name))
                .toList();
          },
          onSelected: (s) {
            widget.setThemeCallback(s);
          },
        ),
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
        IconButton(
            onPressed: () {},
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
            child: titleWidget(),
          ),
          Expanded(
            child: subInfoList(),
          ),
        ],
      ),
    );
  }

  Widget titleWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        _state.info ?? "-",
        textAlign: TextAlign.center,
        softWrap: true,
        maxLines: 3,
        overflow: TextOverflow.fade,
        style: Theme.of(context).textTheme.headline1,
      ),
    );
  }

  Widget subInfoList() {
    var children = _state.subInfos
        .map((entry) => subInfoRow(entry))
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: children,
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

  Widget subInfoRow(SubInfo si) {
    return Row(
      key: si.key,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Icon(
            infoTypeToIcon(si.type),
            size: Theme.of(context).textTheme.headline2?.fontSize,
          ),
        ),
        Flexible(
          child: Text(
            si.text,
            textAlign: TextAlign.left,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            maxLines: 2,
            style: Theme.of(context).textTheme.headline2,
          ),
        ),
      ],
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
