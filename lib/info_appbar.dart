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
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'about.dart';
import 'data_classes.dart';
import 'info.dart';
import 'mpd_client.dart';

class InfoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const InfoAppBar({
    Key? key,
    required this.context,
    required this.infoState,
    required this.mpd,
    required this.onSliderChanged,
  }) : super(key: key);

  final BuildContext context;
  final InfoState infoState;
  final MPDClient mpd;
  final void Function(double v) onSliderChanged;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      IconButton(
          onPressed: infoState.info.state == PlayState.stopped
              ? null
              : () => mpd.sendCommand("previous"),
          icon: const Icon(Icons.skip_previous),
          tooltip: 'Previous'),
      IconButton(
          onPressed: () {
            switch (infoState.info.state) {
              case PlayState.stopped:
                mpd.sendCommand("play");
                break;
              case PlayState.paused:
                mpd.sendCommand("pause 0");
                break;
              case PlayState.playing:
                mpd.sendCommand("pause 1");
            }
          },
          icon: infoState.info.state == PlayState.playing
              ? const Icon(Icons.pause)
              : const Icon(Icons.play_arrow),
          tooltip: 'Album'),
      IconButton(
          onPressed: infoState.info.state == PlayState.stopped
              ? null
              : () => mpd.sendCommand("next"),
          icon: const Icon(Icons.skip_next),
          tooltip: 'Pause'),
      const VerticalDivider(),
      IconButton(
          icon: const Icon(Icons.text_format),
          onPressed: () {
            _displayThemeDialog(context);
          }),
      IconButton(
          onPressed: () {
            _displayServerDialog(context, mpd);
          },
          icon: const Icon(Icons.settings_ethernet),
          tooltip: 'Set MPD Server'),
      IconButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AboutPage()),
          );
        },
        icon: const Icon(Icons.info),
      ),
    ].map((w) => Transform.scale(scale: 1.5, child: w)).toList();
    return AppBar(
      title: Row(
        children: [
          Expanded(
            child: infoState.info.duration > 0
                ? Slider(
                    onChangeStart: (startVal) {
                      infoState.sliderUpdateEnabled = false;
                      infoState.estimatedElapsed = startVal;
                    },
                    onChanged: onSliderChanged,
                    onChangeEnd: (endVal) {
                      // sanity check in case the track changed during drag
                      infoState.estimatedElapsed =
                          endVal <= infoState.info.duration
                              ? endVal
                              : infoState.info.duration - 0.1;
                      infoState.sliderUpdateEnabled = true;
                      mpd.sendCommand("seekcur ${infoState.estimatedElapsed}");
                    },
                    value: infoState.estimatedElapsed,
                    min: 0,
                    // if min == max, slider is disabled, so force that if we are stopped
                    max: infoState.info.state == PlayState.stopped
                        ? 0
                        : infoState.info.duration,
                  )
                : Container(),
          ),
        ],
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  TextEditingValue _ipPort(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      // we have to allow blanks, otherwise we can't delete the last digit
      return newValue;
    }
    final port = int.tryParse(newValue.text);
    if (port == null || port <= 0 || port >= 65536) {
      return oldValue;
    }
    return newValue;
  }

  Future<void> _displayServerDialog(BuildContext context, MPDClient mpd) async {
    var oneLine = FilteringTextInputFormatter.singleLineFormatter;
    var portOnly = TextInputFormatter.withFunction(_ipPort);
    String? mpdServer;
    int? mpdPort;

    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("MPD Server"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    onChanged: (value) {
                      mpdServer = value;
                    },
                    inputFormatters: [oneLine],
                    controller: TextEditingController(text: mpd.server),
                    decoration:
                        const InputDecoration(hintText: "Name or IP address"),
                  ),
                  TextField(
                    onChanged: (value) {
                      mpdPort = int.parse(
                          value); // no need to catch exception, ipPort() has validated it already
                    },
                    inputFormatters: [portOnly],
                    controller:
                        TextEditingController(text: mpd.port.toString()),
                    decoration: const InputDecoration(
                        hintText: "Port number (default 6600)"),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text("Connect"),
                onPressed: () {
                  mpd.setServer(mpdServer, mpdPort);
                  Navigator.pop(context);
                },
              ),
              TextButton(
                child: const Text("Cancel"),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        });
  }

  Future<void> _displayThemeDialog(BuildContext context) async {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Appearance"),
            content: Consumer<PageState>(
                builder: (context, pageState, child) => SingleChildScrollView(
                      child: Column(children: [
                        DropdownButton<String>(
                          value: pageState.fontThemeName,
                          items: pageState
                              .fontThemeNames()
                              .map((name) => DropdownMenuItem(
                                    child: Text(name),
                                    value: name,
                                  ))
                              .toList(),
                          onChanged: (s) {
                            if (s != null) {
                              pageState.setFontThemeName(s);
                            }
                          },
                        ),
                        DropdownButton<String>(
                          value: pageState.appearanceThemeName,
                          items: pageState
                              .appearanceThemeNames()
                              .map((name) => DropdownMenuItem(
                                    child: Text(name),
                                    value: name,
                                  ))
                              .toList(),
                          onChanged: (s) {
                            if (s != null) {
                              pageState.setAppearanceThemeName(s);
                            }
                          },
                        ),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                onPressed: pageState.canDecFontSize()
                                    ? () {
                                        pageState.decFontSize();
                                      }
                                    : null,
                                icon: const Icon(Icons
                                    .arrow_downward), // text_decrease is blank - bug?
                                tooltip: "Reduce text size",
                              ),
                              Text(pageState.fontSizeDescription()),
                              IconButton(
                                onPressed: pageState.canIncFontSize()
                                    ? () {
                                        pageState.incFontSize();
                                      }
                                    : null,
                                icon: const Icon(Icons
                                    .arrow_upward), // text_increase is blank - bug?
                                tooltip: "Increase text size",
                              ),
                            ])
                      ]),
                    )),
            actions: <Widget>[
              TextButton(
                child: const Text("Done"),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        });
  }
}
