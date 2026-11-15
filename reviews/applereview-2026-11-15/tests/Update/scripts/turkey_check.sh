#!/bin/bash
# Records the header for 10 s after a cold launch with -demoTurkey (any week is Thanksgiving
# week) on the app's real data (no throwaway flags), and makes a contact sheet of the header.
#   turkey_check.sh <name>      -> shots/<name>.mp4, shots/<name>-sheet.png
HERE="$(cd "$(dirname "$0")" && pwd)"
UDID=795888E6-590B-4F10-9E66-A838A37D18DD
NAME=${1:-turkey}
xcrun simctl terminate $UDID com.symonym.Tasquel 2>/dev/null
sleep 1
xcrun simctl io $UDID recordVideo --codec=h264 --force "$HERE/$NAME.mp4" > /dev/null 2>&1 &
REC=$!
sleep 1.5
xcrun simctl launch $UDID com.symonym.Tasquel -demoTurkey $EXTRA_ARGS
sleep 10
kill -INT $REC; sleep 2
"$HERE/header_sheet" "$HERE/$NAME.mp4" "$HERE/$NAME-sheet.png" "3,3.5,4,4.5,5,5.5,6,6.5,7,7.5,8,9"
echo "$HERE/$NAME-sheet.png"
