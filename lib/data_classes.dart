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

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InfoFontTheme {
  static const double _defaultTitleSize =
      76; // default font sizes unless overridden
  static const double _defaultInfoSize = 60;
  static const _defaultWeight = FontWeight.normal;

  String? font;
  double titleSize;
  double infoSize;
  double height;
  FontWeight weight;

  InfoFontTheme({
    this.font,
    this.titleSize = _defaultTitleSize,
    this.infoSize = _defaultInfoSize,
    this.height =
        1.0, // 1.0 is almost always unacceptable but we need a value so we can do lines calculations later
    this.weight = _defaultWeight,
  });
}

class InfoAppearanceTheme {
  Color? bgColor;
  Color? titleColor;
  Color? infoColor;
  Color? infoIconColor;

  InfoAppearanceTheme({
    this.bgColor,
    this.titleColor,
    this.infoColor,
    this.infoIconColor,
  });
}

class PageState extends ChangeNotifier {
  String _fontThemeName = "Clean";
  String _appearanceThemeName = "Readable Blue";
  int _fontSizeOffset = 0;
  static const fontOffsetLimit = 3;

  PageState() : super() {
    _loadTheme();
  }

  String get fontThemeName => _fontThemeName;
  String get appearanceThemeName => _appearanceThemeName;

  List<String> fontThemeNames() => _fontThemes.keys.toList();
  List<String> appearanceThemeNames() => _appearanceThemes.keys.toList();

  String defaultFontTheme() => _fontThemes.keys.first;
  int defaultFontSizeOffset() => 0;
  String defaultAppearanceTheme() => _appearanceThemes.keys.first;

  InfoFontTheme? fontTheme() => _fontThemes[fontThemeName] ?? InfoFontTheme();
  InfoAppearanceTheme? appearanceTheme() =>
      _appearanceThemes[appearanceThemeName] ?? InfoAppearanceTheme();

  String fontSizeDescription() =>
      "${_fontSizeOffset == 0 ? " " : ""}$_fontSizeOffset";
  double fontFactor() => 1 + (_fontSizeOffset * 0.1);

  void setFontThemeName(String name) {
    if (_fontThemes.containsKey(name)) {
      _fontThemeName = name;
      _saveTheme();
      notifyListeners();
    }
  }

  void setAppearanceThemeName(String name) {
    if (_appearanceThemes.containsKey(name)) {
      _appearanceThemeName = name;
      _saveTheme();
      notifyListeners();
    }
  }

  void setThemeAndFontSize(String fontName, String appearanceName, int fontSz) {
    _fontThemeName = fontName;
    _appearanceThemeName = appearanceName;
    _fontSizeOffset = fontSz;
    _saveTheme();
    notifyListeners();
  }

  bool canIncFontSize() {
    return _fontSizeOffset < fontOffsetLimit;
  }

  void incFontSize() {
    if (canIncFontSize()) {
      ++_fontSizeOffset;
      _saveTheme();
      notifyListeners();
    }
  }

  bool canDecFontSize() {
    return _fontSizeOffset > -fontOffsetLimit;
  }

  void decFontSize() {
    if (canDecFontSize()) {
      --_fontSizeOffset;
      _saveTheme();
      notifyListeners();
    }
  }

  void _saveTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('fonttheme', _fontThemeName);
    await prefs.setString('appearancetheme', _appearanceThemeName);
    await prefs.setInt('fontsize', _fontSizeOffset);
  }

  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var fontName = prefs.getString('fonttheme') ?? defaultFontTheme();
    // if font theme names have changed, ignore an invalid value
    if (!_fontThemes.containsKey(fontName)) {
      fontName = _fontThemes.keys.first;
    }
    var appearanceName =
        prefs.getString('appearancetheme') ?? defaultAppearanceTheme();
    // if appearance theme names have changed, ignore an invalid value
    if (!_appearanceThemes.containsKey(appearanceName)) {
      appearanceName = _appearanceThemes.keys.first;
    }
    final fontSz = prefs.getInt('fontsize') ?? defaultFontSizeOffset();
    setThemeAndFontSize(fontName, appearanceName, fontSz);
  }

  static final _fontThemes = {
    "Standard": InfoFontTheme(
      font: "Roboto",
      height: 1.20,
      weight: FontWeight.w600,
    ),
    "Formal": InfoFontTheme(
      font: "NotoSerif",
      height: 1.20,
      weight: FontWeight.w600,
    ),
    "Renaissance": InfoFontTheme(
      font: "Garamond",
      titleSize: 84,
      infoSize: 68,
      height: 1.1,
      weight: FontWeight.w600,
    ),
    "Baroque": InfoFontTheme(
      font: "Baskerville",
      titleSize: 76,
      infoSize: 60,
      height: 1.1,
      weight: FontWeight.w600,
    ),
    "Headline": InfoFontTheme(
      font: "DMSerif",
      titleSize: 84,
      infoSize: 70,
      height: 1.1,
    ),
    "70s": InfoFontTheme(
      font: "Righteous",
      titleSize: 80,
      infoSize: 64,
      height: 1.1,
    ),
    "Techno": InfoFontTheme(
      font: "Jura",
      titleSize: 80,
      infoSize: 64,
      height: 1.0,
    ),
    "Matrix": InfoFontTheme(
      font: "Dot",
      titleSize: 86,
      infoSize: 66,
      height: 1.0,
    ),
  };

  static final _appearanceThemes = {
    "Gold": InfoAppearanceTheme(
      bgColor: const Color(0xff151538),
      titleColor: const Color(0xffffd700),
      infoColor: const Color(0xffe0e0e0),
    ),
    "Nightsky": InfoAppearanceTheme(
      bgColor: const Color(0x80483475),
      titleColor: const Color(0xffffffff),
      infoColor: const Color(0xffd0d0ff),
    ),
    "Rainforest": InfoAppearanceTheme(
      bgColor: const Color(0x806e2e05),
      titleColor: const Color(0xfff8bf00),
      infoColor: const Color(0xff87df25),
    ),
    "Parchment": InfoAppearanceTheme(
      bgColor: const Color(0xfff7ecc3),
      titleColor: const Color(0xff101040),
      infoColor: const Color(0xff202020),
    ),
    "VFD": InfoAppearanceTheme(
      bgColor: const Color(0xff000000),
      titleColor: const Color(0xff11ffee),
      infoColor: const Color(0xff11ffee),
    ),
    "Light": InfoAppearanceTheme(
      bgColor: Colors.white,
      titleColor: Colors.black,
      infoColor: Colors.black,
    ),
    "Dark": InfoAppearanceTheme(
      bgColor: Colors.black,
      titleColor: Colors.white,
      infoColor: Colors.white,
    ),
  };
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
  station,
  genre,
  queueinfo,
  technical
}

/* represents a word within a subinfo text and the associated global key, so it
can be scrolled to */

class WordKey {
  String word;
  final key = GlobalKey();

  WordKey(this.word);

  void trimRight() {
    word = word.trimRight();
  }
}

/*
Represents a combination of a type and a piece of text;
usually this is something like { Icons.album, "Some album name" }
*/

class SubInfo {
  InfoType type;
  String text;
  List<WordKey> wordKeys = [];

  SubInfo(this.type, this.text) {
    for (final word in text.split(" ").where((word) => word.isNotEmpty)) {
      wordKeys.add(WordKey("$word "));
    }
    wordKeys.last.trimRight();
  }

  @override
  bool operator ==(Object other) {
    return (other is SubInfo && type == other.type && text == other.text);
  }

  @override
  int get hashCode {
    return type.hashCode ^ text.hashCode;
  }
}

class Info {
  static final timeFormat = NumberFormat("00");
  bool isInfo; // if true, actual info, if false, special message
  String? info; // the current track title or perhaps a status message
  Set<SubInfo> subInfos = {};
  PlayState state = PlayState.stopped;
  bool connected = false;
  bool repeat = false;
  bool random = false;
  bool single = false;
  bool consume = false;
  double duration = 0; // seconds
  double elapsed = 0; // seconds
  double timestamp = 0; // when this info was created
  int song = -1; // position in the playlist
  int playlistlength = 0; // length of the playlist
  String? fileType; // e.g. FLAC

  Info({this.connected = false, this.isInfo = true, this.info}) {
    timestamp = DateTime.now().millisecondsSinceEpoch.toDouble() / 1000;
  }

  void setFiletypeFromPath(String? name) {
    if (name != null) {
      final components = name.split(".");
      if (components.length > 1) {
        fileType = components.last.toUpperCase();
      }
    }
  }

  void add(InfoType type, String val) {
    subInfos.add(SubInfo(type, val));
  }

  void addAll(InfoType type, List<String>? vals) {
    for (final val in vals ?? []) {
      subInfos.add(SubInfo(type, val));
    }
  }

  String durationToString() =>
      "${timeFormat.format(duration.round() ~/ 60)}:${timeFormat.format(duration.round() % 60)}";

  bool hasData() => (info != null) || subInfos.isNotEmpty;

  bool isEmpty() => (info == null) && subInfos.isEmpty;

  @override
  String toString() {
    return "info $info subinfos ${subInfos.length}${repeat ? " [Rpt]" : ""}${random ? " [Rnd]" : ""}${single ? " [Sgl]" : ""}";
  }
}
