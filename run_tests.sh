#!/bin/bash

PASS=0
FAIL=0
FAILED_FILES=""

run_test() {
  local file=$1
  local output
  output=$(fardrun test --program "$file" 2>&1)
  echo "$output"

  local p=$(echo "$output" | grep -oE "[0-9]+ passed" | grep -oE "^[0-9]+")
  local f=$(echo "$output" | grep -oE "[0-9]+ failed" | grep -oE "^[0-9]+")

  PASS=$((PASS + ${p:-0}))
  FAIL=$((FAIL + ${f:-0}))

  if [ "${f:-0}" -gt 0 ]; then
    FAILED_FILES="$FAILED_FILES $file"
  fi
}

echo "=== EOS Test Suite ==="
echo ""

run_test tests/test_k1.fard
run_test tests/test_claim.fard
run_test tests/test_gate.fard
run_test tests/test_witness.fard
run_test tests/test_kernel.fard
run_test tests/test_azim_bridge.fard
run_test tests/test_policy_compile.fard
run_test tests/test_fda_policy.fard
run_test tests/test_witnessd.fard
run_test tests/test_challenge.fard
run_test tests/test_discover.fard

echo ""
echo "========================="
echo "  total  $PASS passed  $FAIL failed"
echo "========================="

if [ "$FAIL" -gt 0 ]; then
  echo "FAILED: $FAILED_FILES"
  exit 1
fi
