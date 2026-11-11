#!/bin/bash
# Watches for the System Dark test's requests and switches my simulator's appearance.
D=/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Settings/shots
for i in $(seq 1 1200); do
  if [ -f $D/appearance-request ]; then
    want=$(cat $D/appearance-request); rm -f $D/appearance-request
    xcrun simctl ui 3F72586A-B9F5-4E33-85FF-E17A01F5AA44 appearance $want
    echo "$(date +%T) set $want" >> $D/appearance-helper.log
    echo $want > $D/appearance-done
  fi
  sleep 0.5
done
