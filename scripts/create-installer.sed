/^# WAKEUP-SCRIPT/ {
  r wakeup-mpd-display.sh
  d
}
/^# WAKEUP-SERVICE/ {
  r wakeup-mpd-display.service
  d
}
