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
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

mixin TextUtil {
  pad(String text, TextStyle? style) {
    return Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(
          text,
          style: style,
        ));
  }
}

class AboutPage extends StatefulWidget {
  AboutPage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _AboutPageState createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with TextUtil {
  static const title = 'MPD Display';
  static const url = 'https://apps.joat.me/page/mpd-display/';
  static const ppUrl = 'https://apps.joat.me/page/privacy';
  static const copyYear = '2021';
  static const copyright = 'Fraser McCrossan';
  static const fontCopy = 'The fonts used in this application have been chosen for their readability at a distance. "Clean" themes use the font Noto Sans, "Formal" themes use Noto Serif, and "Baroque" themes use EB Garamond, all from Google Fonts.';
  static const license =
      'This program comes with ABSOLUTELY NO WARRANTY. This is free software, and you are welcome to redistribute it under certain conditions';
  String _version = '';

  @override
  void initState() {
    super.initState();
    _fetchVersion();
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          pad(title, theme.headline5),
          pad('Version $_version', theme.bodyText2),
          pad('Copyright ⓒ $copyYear $copyright', theme.bodyText2),
          pad(fontCopy, theme.bodyText2),
          pad(license, theme.bodyText1),
          Expanded(
              child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ButtonBar(
                    alignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                          onPressed: () {
                            _launchURL(url);
                          },
                          child: Text(
                            'App page',
                          )),
                      TextButton(
                          onPressed: () {
                            _launchURL(ppUrl);
                          },
                          child: Text(
                            'Privacy Policy',
                          )),
                    ],
                  ))),
        ],
      ),
    );
  }

  _fetchVersion() async {
    PackageInfo info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
    });
  }

  _launchURL(String url) async {
    print("launching $url");
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
