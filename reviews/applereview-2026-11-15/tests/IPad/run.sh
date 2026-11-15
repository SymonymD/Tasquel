#!/bin/bash
# usage: run.sh <udid> <logname> <Class/test> [<Class/test> ...]
R=/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15/IPad
UDID=$1; shift; LOG=$1; shift
ONLY=""
for t in "$@"; do ONLY="$ONLY -only-testing:TasquelUITests/$t"; done
cd $R/project
TEST_RUNNER_SHOT_DIR=$R/shots caffeinate -dims xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination "id=$UDID" \
  -derivedDataPath $R/derived -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 240 \
  $ONLY test > $R/shots/$LOG.log 2>&1
grep -E "error:|Test Case|REVIEW|XCTAssert|failed -|\.xcresult" $R/shots/$LOG.log | grep -v "^    t = " | head -150
