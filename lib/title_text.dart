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

class TitleText extends StatelessWidget {
  const TitleText({
    Key? key,
    required Info state,
    required this.context,
  }) : _info = state, super(key: key);

  final Info _info;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        _info.info ?? "-",
        textAlign: TextAlign.center,
        softWrap: true,
        maxLines: 3,
        overflow: TextOverflow.fade,
        style: Theme.of(context).textTheme.headline1,
      ),
    );
  }
}
