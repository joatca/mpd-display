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
        scrollPoints.add(wk.key);
      }
    }
  }
}

class InfoWidget extends StatefulWidget {
  const InfoWidget({Key? key, required this.mpd, required this.title})
      : super(key: key);

  final MPDClient mpd;
  final String title;

  @override
  State<InfoWidget> createState() => _InfoWidgetState();
}

class _InfoWidgetState extends State<InfoWidget> with WidgetsBindingObserver {
  var _state = InfoState();
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
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
    okGo();
  }

  @override
  void dispose() {
    stopThat();
    WidgetsBinding.instance?.removeObserver(this);
    subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      stopThat();
    }
    if (state == AppLifecycleState.resumed) {
      okGo();
    }
  }

  void okGo() {
    infoStream = widget.mpd.infoStream();
    startListening();
    ticker = Timer.periodic(const Duration(seconds: 1), tickScroll);
  }

  void stopThat() {
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
          return emptyLayout(context, constraints,
              Icons.signal_wifi_connected_no_internet_4, _state.info.info);
        } else if (_state.info.isEmpty()) {
          return emptyLayout(context, constraints, Icons.queue_music);
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
    final textStyle = Theme.of(context).textTheme.headline1;
    return Center(
      child: Column(
        children: [
          Icon(
            icon,
            size: textStyle?.fontSize,
            color: textStyle?.color,
          ),
          Text(msg ?? "${widget.mpd.server}:${widget.mpd.port}",
              style: textStyle),
        ],
      ),
    );
  }

  void tickScroll(Timer timer) async {
    if (_state.sliderUpdateEnabled && _state.info.state == PlayState.playing) {
      setState(() {
        // always update the current time, we use it whether paused or playing
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
      // converting elapsed time directly to seconds gives us one word per second
      final wantedScroll = (_state.estimatedElapsed.toInt())
          .remainder(_state.scrollPoints.length);
      if (wantedScroll != currentScroll) {
        currentScroll = wantedScroll;
        scrollTo(currentScroll);
      }
    }
  }

  void scrollTo(int pos) async {
    final cntxt = _state.scrollPoints[pos].currentContext;
    if (cntxt != null) {
      Scrollable.ensureVisible(
        cntxt,
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOut,
        // this prioritizes the first lines, doesn't scroll until it absolutely
        // has to, and makes the last line the least visible
        alignmentPolicy: pos == 0
            ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
            : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    }
  }

  void startListening() async {
    if (subscription == null) {
      subscription = infoStream.listen((info) {
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
      });
    } else {
      if (subscription?.isPaused ?? false) {
        subscription?.resume();
      }
    }
  }

  void stopListening() {
    subscription?.pause();
  }
}
