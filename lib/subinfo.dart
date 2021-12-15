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
import 'data_classes.dart';

class SubInfoList extends StatelessWidget {
  const SubInfoList({
    Key? key,
    required this.context,
    required this.subInfos,
  }) : super(key: key);

  final BuildContext context;
  final List<SubInfo> subInfos;

  @override
  Widget build(BuildContext context) {
    var children = subInfos.map((si) => SubInfoRow(context: context, subInfo: si)).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
  }) : super(key: key);

  final BuildContext context;
  final SubInfo subInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: subInfo.key,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Icon(
            infoTypeToIcon(subInfo.type),
            size: Theme.of(context).textTheme.headline2?.fontSize,
          ),
        ),
        Flexible(
          child: Text(
            subInfo.text,
            textAlign: TextAlign.left,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            maxLines: 2,
            style: Theme.of(context).textTheme.headline2,
          ),
        ),
      ],
    );
  }

  IconData infoTypeToIcon(InfoType type) {
    switch (type) {
      case InfoType.album:
        return Icons.album;
      case InfoType.composer:
        return Icons.edit;
      case InfoType.performer:
        return Icons.piano;
      default:
        return Icons.device_unknown;
    }
  }
}
