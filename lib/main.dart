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
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'data_classes.dart';
import 'main_page.dart';

void main() {
  runApp(ChangeNotifierProvider(
      create: (context) => PageState(), child: const MpdDisplayApp()));
}

class MpdDisplayApp extends StatelessWidget {
  const MpdDisplayApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // full-screen mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    return const MaterialApp(
      title: 'MPD Display',
      home: MainPage(title: 'MPD Display'),
    );
  }
}
