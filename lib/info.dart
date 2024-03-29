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

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wakelock/wakelock.dart';
import 'data_classes.dart';
import 'mpd_client.dart';
import 'info_appbar.dart';
import 'title.dart';
import 'subinfo.dart';

class InfoState {
  Info _info = Info();
  double estimatedElapsed = 0;
  var sliderUpdateEnabled = true;
  double currentTime = 0;
  List<GlobalKey> scrollPoints = [];

  // ignore: unnecessary_getters_setters
  Info get info => _info;

  set info(Info i) {
    _info = i;
    // here we can do further processing
    scrollPoints.clear();
    for (var si in _info.subInfos) {
      for (var wk in si.wordKeys) {
        if (wk.length > 1) { // don't scroll to single-character "words"
          scrollPoints.add(wk.key);
        }
      }
    }
  }
}

class InfoWidget extends StatefulWidget {
  const InfoWidget(
      {Key? key,
      required this.mpd,
      required this.pageState,
      required this.title})
      : super(key: key);

  final MPDClient mpd;
  final PageState pageState;
  final String title;

  @override
  State<InfoWidget> createState() => _InfoWidgetState();
}

class _InfoWidgetState extends State<InfoWidget> with WidgetsBindingObserver {
  final _state = InfoState();
  late Stream<Info> infoStream;
  StreamSubscription<Info>? subscription;
  int currentScroll = 0;
  int scrollDirection = 1;
  Timer? ticker;
  final gestureKey =
      GlobalKey(); // used to fetch size of text area when processing taps

  _InfoWidgetState();

  @override
  void initState() {
    if (kDebugMode) {
      print("initState");
    }
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    okGo();
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print("dispose");
    }
    stopThat();
    WidgetsBinding.instance.removeObserver(this);
    subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (kDebugMode) {
        print("lifecycle paused");
      }
      stopThat();
    }
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) {
        print("lifecycle resumed");
      }
      okGo();
    }
  }

  void okGo() {
    if (kDebugMode) {
      print("okGo");
    }
    infoStream = widget.mpd.infoStream();
    startListening();
    ticker ??= Timer.periodic(const Duration(milliseconds: 200), tickScroll);
  }

  void stopThat() {
    if (kDebugMode) {
      print("stopThat");
    }
    ticker?.cancel();
    ticker = null;
    stopListening();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InfoAppBar(
          context: context,
          infoState: _state,
          pageState: widget.pageState,
          mpd: widget.mpd,
          onSliderChanged: (val) {
            if (val <= _state.info.duration) {
              setState(() {
                _state.estimatedElapsed = val;
              });
            } else {
              // if the value is greater than the duration then something weird happened, resync the current status
              widget.mpd.getStatus();
            }
          }),
      body: LayoutBuilder(builder: (context, constraints) {
        if (!_state.info.connected) {
          return emptyLayout(
              context, constraints, Icons.cloud_off, _state.info.info);
        } else if (_state.info.isEmpty()) {
          return emptyLayout(context, constraints, Icons.stop);
        } else {
          return playingLayout(context, constraints, _state.info);
        }
      }),
    );
  }

  Widget playingLayout(
      BuildContext context, BoxConstraints constraints, Info info) {
    return GestureDetector(
      key: gestureKey,
      onTapUp: (details) {
        final box = gestureKey.currentContext?.findRenderObject();
        if (box is RenderBox) {
          final width = box.size.width;
          final tapPosition = details.localPosition.dx;
          if (tapPosition < width * 0.25) {
            widget.mpd.sendCommand("previous");
          } else if (tapPosition > width * 0.75) {
            widget.mpd.sendCommand("next");
          } else {
            widget.mpd.sendCommand("pause");
          }
        }
      },
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            TitleText(
              state: info,
              context: context,
              box: constraints,
              paddingBase: 8,
            ),
            Expanded(
              child: SubInfoList(
                context: context,
                subInfos: info.subInfos,
                box: constraints,
                paddingBase: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget emptyLayout(
      BuildContext context, BoxConstraints constraints, IconData icon,
      [String? msg]) {
    final textStyle = Theme.of(context).textTheme.displayLarge;
    return Center(
      child: Column(
        children: [
          Icon(
            icon,
            size: textStyle?.fontSize,
            color: textStyle?.color,
          ),
          Text(
              msg ??
                  "${widget.mpd.server}${widget.mpd.port == 6600 ? "" : ":${widget.mpd.port}"}",
              style: textStyle),
        ],
      ),
    );
  }

  void tickScroll(Timer timer) async {
    if (_state.sliderUpdateEnabled && _state.info.state == PlayState.playing) {
      setState(() {
        _state.currentTime =
            DateTime.now().millisecondsSinceEpoch.toDouble() / 1000;
        // compute the actual elapsed time based on the elapsed value in the info
        // plus the time difference between when the info was created and now
        final elapsedOffset = _state.currentTime - _state.info.timestamp;
        final targetElapsed = _state.info.elapsed + elapsedOffset;
        // sanity check in case track changed
        if (targetElapsed <= _state.info.duration) {
          _state.estimatedElapsed = _state.info.elapsed + elapsedOffset;
        }
      });
    }
    if (_state.scrollPoints.isNotEmpty) {
      // converting time between last info update and now directly to seconds
      // gives us one word per second; the extra 3 and constraining min() gives
      // us a short pause on the final line; the scroll thus resets to the top
      // whenever anything changes
      final wantedScroll = min(
          max(0, (_state.currentTime - _state.info.timestamp))
              .toInt()
              .remainder(_state.scrollPoints.length + 3),
          _state.scrollPoints.length - 1);
      if (wantedScroll != currentScroll) {
        currentScroll = wantedScroll;
        scrollTo(currentScroll);
      }
    }
  }

  void scrollTo(int pos) async {
    final cntxt = _state.scrollPoints[pos].currentContext;
    if (cntxt != null) {
      await Scrollable.ensureVisible(
        cntxt,
        duration: const Duration(seconds: 1),
        curve: pos == 0 ? Curves.easeInOutCubicEmphasized : Curves.easeInOut,
        // this prioritizes the first lines, doesn't scroll until it absolutely
        // has to, and makes the last line the least visible
        alignmentPolicy: pos == 0
            ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
            : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    }
  }

  void startListening() async {
    if (kDebugMode) {
      print("startListening");
    }
    if (subscription == null) {
      if (kDebugMode) {
        print("startListening subscription was null");
      }
      subscription = infoStream.listen((info) {
        if (info.isInfo) {
          setState(() {
            if (info.state == PlayState.playing) {
              Wakelock.enable();
            } else {
              Wakelock.disable();
            }
            _state.info = info;
            if (_state.sliderUpdateEnabled) {
              _state.estimatedElapsed = _state.info.elapsed;
            }
          });
          if (info.state != PlayState.stopped && info.subInfos.isNotEmpty) {
            scrollTo(0);
          }
        } else {
          // this is a text message to be interpreted by the app (setting theme)
          final msg = info.info;
          if (msg != null) {
            final words = msg.split("=").toList();
            if (words.length == 2) {
              switch (words[0]) {
                case "f":
                  widget.pageState.setFontThemeName(words[1]);
                  break;
                case "a":
                  widget.pageState.setAppearanceThemeName(words[1]);
                  break;
              }
            }
          }
        }
      });
    } else {
      if (kDebugMode) {
        print(
            "subscription not null $subscription isPaused ${subscription?.isPaused}");
      }
      if (subscription?.isPaused ?? false) {
        if (kDebugMode) {
          print("resuming paused subscription");
        }
        subscription?.resume();
      }
    }
  }

  void stopListening() {
    if (kDebugMode) {
      print("stopListening");
    }
    if (subscription?.isPaused ?? true) {
      if (kDebugMode) {
        print("subscription already paused");
      }
    } else {
      if (kDebugMode) {
        print("subscription paused");
      }
      subscription?.pause();
    }
  }
}
