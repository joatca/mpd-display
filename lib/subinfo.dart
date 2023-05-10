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

class SubInfoList extends StatelessWidget {
  const SubInfoList({
    Key? key,
    required this.context,
    required this.subInfos,
    required this.box,
    required this.paddingBase,
  }) : super(key: key);

  final BuildContext context;
  final List<SubInfo> subInfos;
  final BoxConstraints box;
  final double paddingBase;

  @override
  Widget build(BuildContext context) {
    // compute how many subinfo text lines will fit in roughtly half of the screen
    final theme = Theme.of(context).textTheme.displayMedium;
    final double fontSize = (theme?.fontSize ?? 1) * (theme?.height ?? 1);
    // in case fontSize above was null make lines at least 3
    final lines = max(3, (box.maxHeight ~/ fontSize ~/ 2));
    var children = subInfos
        .map((si) => SubInfoRow(context: context, subInfo: si, lines: lines))
        .toList();
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: paddingBase * 2, vertical: paddingBase),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class SubInfoRow extends StatelessWidget {
  const SubInfoRow({
    Key? key,
    required this.context,
    required this.subInfo,
    required this.lines,
  }) : super(key: key);

  final BuildContext context;
  final SubInfo subInfo;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final subInfoStyle = Theme.of(context).textTheme.displayMedium;
    final iconSize =
        (subInfoStyle?.fontSize ?? 1) * (subInfoStyle?.height ?? 1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Icon(
            infoTypeToIcon(subInfo.type),
            color: subInfoStyle?.color,
            size: iconSize,
          ),
        ),
        Flexible(
          child: Wrap(
            children: subInfo.wordKeys
                .map((wk) => Text(wk.word, key: wk.key, style: subInfoStyle))
                .toList(),
          ),
        ),
      ],
    );
  }

  IconData infoTypeToIcon(InfoType type) {
    switch (type) {
      case InfoType.album:
        return Icons.album_outlined;
      case InfoType.composer:
        return Icons.history_edu;
      case InfoType.performer:
        return Icons.person_sharp;
      case InfoType.station:
        return Icons.radio;
      case InfoType.queueinfo:
        return Icons.queue_music;
      case InfoType.genre:
        return Icons.label;
      case InfoType.technical:
        return Icons.memory;
      default:
        return Icons.device_unknown;
    }
  }
}
