#!/bin/bash

# set the screen pixel coordinates to swipe up to start the unlock process
SWIPE_FROM="200 500"
SWIPE_TO="200 0"

# PIN CODE, if any (default is blank, no PIN required)
PIN=""

prev_state=""

while true; do
  state="$(mpc status|awk 'NR == 2 { print $1 }')"
  if [ "$state" == "[playing]" -a "$prev_state" != "[playing]" ]; then
    echo Playback started
    adb shell am start me.joat.mpd_display/.MainActivity
    adb shell input keyevent KEYCODE_WAKEUP
    sleep 1
    adb shell input swipe $SWIPE_FROM $SWIPE_TO
    if [ -n "$PIN" ]; then
        adb shell input text "$PIN"
        adb shell input keyevent 66 # "OK"/"Enter"
    fi
  fi
  prev_state="$state"
  mpc idle player >&/dev/null
done
