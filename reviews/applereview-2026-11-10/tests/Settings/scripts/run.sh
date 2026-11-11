#!/bin/bash
# usage: run.sh <logname> <Class/test> [<Class/test> ...]
S=/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Settings
LOG=$S/shots/$1.log; shift
ONLY=""
for t in "$@"; do ONLY="$ONLY -only-testing:TasquelUITests/$t"; done
cd $S/project
TEST_RUNNER_SHOT_DIR=$S/shots xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination 'id=3F72586A-B9F5-4E33-85FF-E17A01F5AA44' \
  -derivedDataPath $S/derived -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 240 \
  $ONLY test > $LOG 2>&1
grep -E "error:|Test Case|REVIEW|\.xcresult" $LOG | grep -v "^\s*$" | head -80
