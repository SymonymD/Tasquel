#!/bin/bash
# usage: runtwb.sh <logname> <Class/test> [...]   (test-without-building; build-for-testing first)
S=/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Settings
LOG=$S/shots/$1.log; shift
ONLY=""
for t in "$@"; do ONLY="$ONLY -only-testing:TasquelUITests/$t"; done
RUN=$(ls $S/derived/Build/Products/*.xctestrun | head -1)
cd $S/project
TEST_RUNNER_SHOT_DIR=$S/shots xcodebuild test-without-building -xctestrun "$RUN" -destination 'id=3F72586A-B9F5-4E33-85FF-E17A01F5AA44' \
  -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  $ONLY > $LOG 2>&1
grep -E "error:|Test Case|REVIEW|\*\* TEST" $LOG | grep -v "nearly passed" | cut -c1-300 | head -80
