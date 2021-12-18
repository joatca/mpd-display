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
import 'package:provider/provider.dart';
import 'data_classes.dart';
import 'mpd_client.dart';
import 'info_widget.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {

  var mpd = MPDClient();

  _MainPageState() {
    // nothing for now
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PageState>(builder: (context, pageState, child) {
      var themeInfo = pageState.theme();
      var textTheme = Theme.of(context).textTheme.copyWith(
            headline1: TextStyle(
              fontFamily: themeInfo?.font,
              fontSize: themeInfo?.titleSize,
              color: themeInfo?.titleColor,
              height: themeInfo?.height,
            ),
            headline2: TextStyle(
              fontFamily: themeInfo?.font,
              fontSize: themeInfo?.infoSize,
              color: themeInfo?.infoColor,
              height: themeInfo?.height,
            ),
          );
      var iconTheme = Theme.of(context).iconTheme.copyWith(
            color: themeInfo?.infoIconColor ?? themeInfo?.infoColor,
          );
      var appbarTheme = Theme.of(context).appBarTheme.copyWith(
            backgroundColor: themeInfo?.bgColor,
            foregroundColor: themeInfo?.titleColor,
          );
      var theme = Theme.of(context).copyWith(
        textTheme: textTheme,
        scaffoldBackgroundColor: themeInfo?.bgColor,
        iconTheme: iconTheme,
        appBarTheme: appbarTheme,
      );
      return Theme(
        data: theme,
        child: InfoWidget(mpd: mpd, title: "MPD Display"),
      );
    });
  }
}
