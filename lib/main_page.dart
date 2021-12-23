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
        final themeInfo = pageState.theme();
      final textTheme = Theme.of(context).textTheme.copyWith(
            headline1: TextStyle(
              fontFamily: themeInfo?.font,
              fontSize: (themeInfo?.titleSize ?? 1) * pageState.fontFactor(),
              color: themeInfo?.titleColor,
              height: themeInfo?.height,
            ),
            headline2: TextStyle(
              fontFamily: themeInfo?.font,
              fontSize: (themeInfo?.infoSize ?? 1) * pageState.fontFactor(),
              color: themeInfo?.infoColor,
              height: themeInfo?.height,
            ),
          );
      final iconTheme = Theme.of(context).iconTheme.copyWith(
            color: themeInfo?.infoIconColor ?? themeInfo?.infoColor,
          );
      final appbarTheme = Theme.of(context).appBarTheme.copyWith(
            backgroundColor: themeInfo?.bgColor,
            foregroundColor: themeInfo?.titleColor,
            iconTheme: iconTheme,
          );
      final sliderColor = themeInfo?.titleColor;
      final sliderTheme = Theme.of(context).sliderTheme.copyWith(
            activeTrackColor: sliderColor?.withOpacity(0.8),
            thumbColor: sliderColor,
            inactiveTrackColor: sliderColor?.withOpacity(0.4),
          );
      final theme = Theme.of(context).copyWith(
        textTheme: textTheme,
        scaffoldBackgroundColor: themeInfo?.bgColor,
        appBarTheme: appbarTheme,
        sliderTheme: sliderTheme,
      );
      return Theme(
        data: theme,
        child: InfoWidget(mpd: mpd, title: "MPD Display"),
      );
    });
  }
}
