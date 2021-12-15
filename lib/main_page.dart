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
import 'mpd_client.dart';
import 'info_widget.dart';

class PageState {
  String themeName = "Clean";

  PageState();
}

// this class will let the sub-widgets look up theme names without a dumb callback
class ThemeNames extends InheritedWidget {
  const ThemeNames({
    Key? key,
    required this.themeNames,
    required Widget child,
  }) : super(key: key, child: child);

  final List<String> themeNames;

  static ThemeNames of(BuildContext context) {
    final ThemeNames? result =
        context.dependOnInheritedWidgetOfExactType<ThemeNames>();
    assert(result != null, 'No ThemeNames found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(ThemeNames oldWidget) =>
      themeNames != oldWidget.themeNames;
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
    this.infoIconColor,
  });
}

class _MainPageState extends State<MainPage> {
  static const double _titleSize = 76;
  static const double _infoSize = 60;

  static var themes = {
    "Clean": InfoTheme(
      font: "NotoSans",
      bgColor: Colors.white,
      titleColor: Colors.black,
      infoColor: Colors.black,
    ),
    "Clean Dark": InfoTheme(
      font: "NotoSans",
      bgColor: Colors.black,
      titleColor: Colors.white,
      infoColor: Colors.white,
    ),
    "Formal": InfoTheme(
      font: "NotoSerif",
      bgColor: Colors.white,
      titleColor: Colors.black,
      infoColor: Colors.black,
    ),
    "Formal Dark": InfoTheme(
      font: "NotoSerif",
      bgColor: Colors.black,
      titleColor: Colors.white,
      infoColor: Colors.white,
      infoIconColor: Colors.white,
    ),
    "Baroque": InfoTheme(
      font: "Garamond",
      bgColor: Colors.white,
      titleColor: Colors.black,
      infoColor: Colors.black,
    ),
    "Baroque Dark": InfoTheme(
      font: "Garamond",
      bgColor: Colors.black,
      titleColor: Colors.white,
      infoColor: Colors.white,
    ),
  };

  var _state = PageState();
  var mpd = MPDClient();

  _MainPageState() {
    // nothing for now
  }

  @override
  void initState() {
    super.initState();
    loadTheme();
  }

  void setThemeName(String name) {
    setState(() {
      _state.themeName = name;
    });
    saveTheme(name);
  }

  void saveTheme(String name) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', name);
  }

  void loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('theme') ?? (themes.keys.first);
    setState(() {
      _state.themeName = name;
    });
  }

  @override
  Widget build(BuildContext context) {
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
        );
    var appbarTheme = Theme.of(context).appBarTheme.copyWith(
          actionsIconTheme: iconTheme,
          backgroundColor: themeInfo?.bgColor,
        );
    var theme = Theme.of(context).copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: themeInfo?.bgColor,
      iconTheme: iconTheme,
      appBarTheme: appbarTheme,
    );
    return Theme(
        data: theme,
        child: ThemeNames(
          themeNames: themes.keys.toList(),
          child: InfoWidget(
              mpd: mpd, setThemeCallback: setThemeName, title: "MPD Display"),
        ));
  }
}
