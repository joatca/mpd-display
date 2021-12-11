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

class MainPage extends StatefulWidget {
  const MainPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  static const double _titleSize = 72;
  static const double _infosize = 56;

  var _state = Info();
  var mpd = MPDClient();
  late Stream<Info> infoStream;
  StreamSubscription<Info>? subscription = null;

  _MainPageState() : super() {
    infoStream = mpd.infoStream();
  }

  @override
  Widget build(BuildContext context) {
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
        IconButton(
            onPressed: startListening,
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
            //height: 2.8 * _titleSize,
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
        maxLines: 4,
        overflow: TextOverflow.fade,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: _titleSize,
          //fontFamily:
        ),
      ),
    );
  }

  Widget subInfoList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: _state.subInfos.map((i) => subInfoRow(i)).toList(),
        ),
      ),
    );
  }

  IconData infoTypeToIcon(InfoType type) {
    switch(type) {
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
  
  Widget subInfoRow(SubInfo i) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: Icon(infoTypeToIcon(i.type), size: _infosize),
        ),
        Flexible(
          child: Text(
            i.text,
            textAlign: TextAlign.left,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            maxLines: 3,
            style: const TextStyle(
              fontSize: _infosize,
            ),
          ),
        ),
      ],
    );
  }

  void startListening() async {
    if (subscription == null) {
      subscription = infoStream.listen((info) {
        setState(() {
          _state = info;
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
}
