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

import 'dart:math';
import 'package:flutter/material.dart';
import 'data_classes.dart';

class TitleText extends StatelessWidget {
  const TitleText({
    Key? key,
    required Info state,
    required this.context,
    required this.box,
    required this.paddingBase,
  })  : _info = state,
        super(key: key);

  final Info _info;
  final BuildContext context;
  final BoxConstraints box;
  final double paddingBase;

  @override
  Widget build(BuildContext context) {
    // compute how many title text lines will fit in roughtly half of the screen
    final titleStyle = Theme.of(context).textTheme.headline1;
    final double titleFontSize =
        (titleStyle?.fontSize ?? 1) * (titleStyle?.height ?? 1);
    final subInfoStyle = Theme.of(context).textTheme.headline1;
    final double subInfoFontSize =
        (subInfoStyle?.fontSize ?? 1) * (subInfoStyle?.height ?? 1);
    // the biggest the title section can be is the height of the render box minus one line of subinfo plus padding
    final maxHeight = box.maxHeight - subInfoFontSize - paddingBase * 2;
    // in case fontSize above was null make lines at least 3
    final maxLines = max(maxHeight ~/ titleFontSize, 1); // make sure we have at least 1 title line
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: paddingBase * 2, vertical: paddingBase),
      child: Text(
        _info.info ?? "-",
        textAlign: TextAlign.center,
        softWrap: true,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.headline1,
      ),
    );
  }
}
