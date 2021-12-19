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
import 'package:shared_preferences/shared_preferences.dart';

class InfoTheme {
  static const double _defaultTitleSize =
      76; // default font sizes unless overridden
  static const double _defaultInfoSize = 60;

  String? font;
  Color? bgColor;
  Color? titleColor;
  Color? infoColor;
  Color? infoIconColor;
  double titleSize;
  double infoSize;
  double? height;

  InfoTheme({
    this.font,
    this.bgColor,
    this.titleColor,
    this.infoColor,
    this.infoIconColor,
    this.titleSize = _defaultTitleSize,
    this.infoSize = _defaultInfoSize,
    this.height = null,
  });
}

class PageState extends ChangeNotifier {
  String _themeName = "Clean";

  static final _themes = {
    "Clean": InfoTheme(
      font: "NotoSans",
      bgColor: Colors.white,
      titleColor: Colors.black,
      infoColor: Colors.black,
      height: 1.20,
    ),
    "Clean Dark": InfoTheme(
      font: "NotoSans",
      bgColor: Colors.black,
      titleColor: Colors.white,
      infoColor: Colors.white,
      height: 1.20,
    ),
    "Formal": InfoTheme(
      font: "NotoSerif",
      bgColor: Colors.white,
      titleColor: Colors.black,
      infoColor: Colors.black,
      height: 1.20,
    ),
    "Formal Dark": InfoTheme(
      font: "NotoSerif",
      bgColor: Colors.black,
      titleColor: Colors.white,
      infoColor: Colors.white,
      infoIconColor: Colors.white,
      height: 1.20,
    ),
    "Baroque": InfoTheme(
      font: "Garamond",
      bgColor: Colors.white,
      titleColor: Colors.black,
      infoColor: Colors.black,
      titleSize: 84,
      infoSize: 68,
      height: 1.1,
    ),
    "Baroque Dark": InfoTheme(
      font: "Garamond",
      bgColor: Colors.black,
      titleColor: Colors.white,
      infoColor: Colors.white,
      titleSize: 84,
      infoSize: 68,
      height: 1.1,
    ),
    "Highway": InfoTheme(
      font: "Interstate",
      bgColor: Color(0xff01A775),
      titleColor: Colors.white,
      infoColor: Colors.white,
      titleSize: 80,
      infoSize: 64,
    ),
    "Highway Dark": InfoTheme(
      font: "Interstate",
      bgColor: Colors.black,
      titleColor: Colors.white,
      infoColor: Colors.white,
      titleSize: 80,
      infoSize: 64,
    ),
  };

  PageState() : super() {
    loadTheme();
  }

  String get themeName => _themeName;
  List<String> themeNames() => _themes.keys.toList();
  String defaultTheme() => _themes.keys.first;
  InfoTheme? theme() => _themes[themeName] ?? InfoTheme();

  void setTheme(String name) {
    _themeName = name;
    saveTheme(name);
    notifyListeners();
  }

  void saveTheme(String name) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', name);
  }

  void loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('theme') ?? defaultTheme();
    setTheme(name);
  }
}

enum PlayState {
  stopped,
  paused,
  playing,
}

enum InfoType {
  album,
  performer,
  composer,
}

/*
Represents a combination of a and a piece of text;
usually this is something like { Icons.album, "Some album name" }
*/
class SubInfo {
  InfoType type;
  String text;
  GlobalKey key = GlobalKey();

  SubInfo(this.type, this.text);
}

class Info {
  String? info; // the current track title or perhaps a status message
  List<SubInfo> subInfos = [];
  PlayState state = PlayState.stopped;
  bool connected = false;
  bool repeat = false;
  bool random = false;
  bool single = false;
  double duration = 0; // seconds
  double elapsed = 0; // seconds
  double timestamp = 0; // when this info was created

  Info({this.connected = false, this.info}) {
    timestamp = DateTime.now().millisecondsSinceEpoch.toDouble() / 1000;
  }

  String toString() {
    return "info $info subinfos ${subInfos.length}${repeat ? " [Rpt]" : ""}${random ? " [Rnd]" : ""}${single ? " [Sgl]" : ""}";
  }
}
