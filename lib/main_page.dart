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
import 'info_widget.dart';

class PageState {
  String themeName = "Manuscript";

  PageState();
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MainPage> createState() => _MainPageState();
}

class InfoTheme {
  String? font;
  Color? bgColor;
  Color? titleColor;
  Color? infoColor;
  Color? infoIconColor;

  InfoTheme({
      this.font,
      this.bgColor,
      this.titleColor,
      this.infoColor,
      this.infoIconColor
  });
}

class _MainPageState extends State<MainPage> {
  static const double _titleSize = 72;
  static const double _infoSize = 56;

  static var themes = {
    "Plain": InfoTheme(
      font: "Roboto",
      bgColor: Colors.white,
      titleColor: Colors.black,
      infoColor: Colors.black,
    ),
    "Manuscript": InfoTheme(
      font: "Baskerville",
      bgColor: Colors.white,
      titleColor: Colors.black,
      infoColor: Colors.black,
    ),
    "Negative Manuscript": InfoTheme(
      font: "Baskerville",
      bgColor: Colors.black,
      titleColor: Colors.white,
      infoColor: Colors.white70,
      infoIconColor: Colors.white,
    ),
    "Classic": InfoTheme(
      font: "Cardo",
      bgColor: Colors.white,
      titleColor: Colors.black,
      infoColor: Colors.black,
    ),
    "Elegance": InfoTheme(
      font: "Parisienne",
      bgColor: Colors.white,
      titleColor: Colors.black,
      infoColor: Colors.black,
    ),
    "Imposing": InfoTheme(
      font: "Playfair",
      bgColor: Colors.black,
      titleColor: Colors.white,
      infoColor: Colors.white70,
    ),
    "8Bit": InfoTheme(
      font: "PressStart",
      bgColor: Colors.black,
      titleColor: Colors.white,
      infoColor: Colors.red,
    ),
    "Cyberpunk": InfoTheme(
      font: "Swerve",
      bgColor: Colors.black,
      titleColor: Colors.pink,
      infoColor: Colors.blue,
      infoIconColor: Colors.green,
    ),
  };

  var _state = PageState();

  _MainPageState() {
    // nothing for now
  }

  @override
  Widget build(BuildContext context) {
    //_state.themeName = "Cyberpunk";
    //_state.themeName = "Manuscript";
    _state.themeName = "Negative Manuscript";
    //_state.themeName = "Classic";
    //_state.themeName = "Elegance";
    //_state.themeName = "8Bit";
    //_state.themeName = "Imposing";
    var themeInfo = themes[_state.themeName];
    var textTheme = Theme.of(context).textTheme.copyWith(
      headline1: TextStyle(
        fontFamily: themeInfo?.font,
        fontSize: _titleSize,
        color: themeInfo?.titleColor,
      ),
      headline2: TextStyle(
        fontFamily: themeInfo?.font,
        fontSize: _infoSize,
        color: themeInfo?.infoColor,
      ),
    );
    var iconTheme = Theme.of(context).iconTheme.copyWith(
      color: themeInfo?.infoIconColor ?? themeInfo?.infoColor,
      size: _infoSize,
    );
    var theme = Theme.of(context).copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: themeInfo?.bgColor,
      iconTheme: iconTheme,
    );
    return Theme(data: theme, child: const InfoWidget(title: "Foo"));
  }
}
