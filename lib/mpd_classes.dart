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

class PlayState {
  String? title; // the current track title
  List<SubInfo> subInfos = [];

  PlayState() {
    title = "(hwv 369) Sonata in F Major, op. 1, no. 11 - 1 Larghetto";
    subInfos.add(SubInfo(Icons.album, "This is a really Long Album Name to see what the Rendering Is Like"));
    subInfos.add(SubInfo(Icons.edit, "J.S. Composer"));
    subInfos.add(SubInfo(Icons.piano, "Jane X. Virtuoso"));
    subInfos.add(SubInfo(Icons.piano, "Simon P. Hack"));
    subInfos.add(SubInfo(Icons.piano, "Mike Notbad"));
    subInfos.add(SubInfo(Icons.piano, "James Obscure"));
  }
}

/*
Everything needed to connect to an MPD server
*/
class MPDServer {
  String host;
  int port;
  String? username; // currently unsupported
  String? password;

  MPDServer(this.host, this.port);

  void authenticate(String username, password) {
    this.username = username;
    this.password = password;
  }
}
