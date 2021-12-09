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

/*
Represents a combination of an icon and a piece of text;
usually this is something like { Icons.album, "Some album name" }
*/
class SubInfo {
  IconData icon;
  String text;

  SubInfo(this.icon, this.text);
}

enum PlayState {
  stopped,
  paused,
  playing,
}

class Info {
  String? info; // the current track title or perhaps a status message
  List<SubInfo> subInfos = [];
  PlayState state = PlayState.stopped;
  bool repeat = false;
  bool random = false;
  bool single = false;
  int duration = 0; // milliseconds
  int elapsed = 0; // milliseconds
  int timestamp = 0; // when this info was created

  Info() {
    timestamp = DateTime.now().millisecondsSinceEpoch;
  }

  String toString() {
    return "info $info subinfos ${subInfos.length}${repeat ? " [Rpt]" : ""}${random ? " [Rnd]" : ""}${single ? " [Sgl]" : ""}";
  }
}
