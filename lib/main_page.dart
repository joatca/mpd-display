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

class MainPage extends StatefulWidget {
  const MainPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    var bar = AppBar(
      title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            onPressed: null,
            icon: const Icon(Icons.skip_previous),
            tooltip: 'Previous'),
          IconButton(
            onPressed: null, icon: const Icon(Icons.pause), tooltip: 'Album'),
          IconButton(
            onPressed: _incrementCounter,
            icon: const Icon(Icons.skip_next),
            tooltip: 'Pause'),
          // IconButton(
          //   onPressed: null, icon: const Icon(Icons.album), tooltip: 'Album'),
          // IconButton(
          //     onPressed: null,
          //     icon: const Icon(Icons.music_note),
          //     tooltip: 'Composer'),
          //   IconButton(
          //     onPressed: null,
          //     icon: const Icon(Icons.person),
          //     tooltip: 'Performer'),
          IconButton(
            onPressed: _incrementCounter,
            icon: const Icon(Icons.sync_problem),
            tooltip: 'Disconnected'),
          IconButton(
            onPressed: null,
            icon: const Icon(Icons.block_sharp),
            tooltip: 'Disconnected'),
          ].map((w) => Transform.scale(scale: 1.5, child: w)).toList(),
      );
    return Scaffold(
      appBar: bar,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
    );
  }
}
