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

import 'package:flutter/material.dart';
import 'mpd_classes.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  static const double _titleSize = 72;
  static const double _infosize = 56;

  var _playState = PlayState();

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
            height: 2.8 * _titleSize,
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
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          _playState.title ?? "-",
          textAlign: TextAlign.center,
          softWrap: true,
          maxLines: 3,
          //overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: _titleSize,
            //fontFamily:
          ),
        ),
    ));
  }

  Widget subInfoList() {
    return Card(
      margin: EdgeInsets.fromLTRB(24, 4, 24, 4),
      child: SingleChildScrollView(
        child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: _playState.subInfos.map((i) => subInfoRow(i)).toList(),
      ),
  ));
  }

  Widget subInfoRow(SubInfo i) {
     return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: Icon(i.icon, size: _infosize),
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
}
