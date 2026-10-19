#!/bin/bash

# A flexible script to run specific chaos experiments.
#
# Usage:
#   ./run_chaos_test.sh {normal|failure|latency|random|all} [--rebuild]
#
# The --rebuild flag is optional. If included, the script will clean and
# build the Xcode project before running the tests.

# Exit immediately if any command fails.
set -e

# --- 1. Parse Command-Line Arguments ---
TEST_TYPE=""
REBUILD=false

# Loop through all arguments provided to the script.
for arg in "$@"; do
  case $arg in
    --rebuild)
      REBUILD=true
      shift # Remove --rebuild from the list of arguments
      ;;
    *)
      # Assume the first non-flag argument is the test type.
      if [ -z "$TEST_TYPE" ]; then
        TEST_TYPE=$arg
      fi
      ;;
  esac
done

if [ -z "$TEST_TYPE" ]; then
    echo "Error: No test type specified."
    echo "Usage: $0 {normal|failure|latency|random|all} [--rebuild]"
    exit 1
fi

# --- 2. Clean and Build the App (if requested) ---
if [ "$REBUILD" = true ]; then
  echo "--- '--rebuild' flag detected. Cleaning and Building Xcode Project ---"
  # Redirecting build output to /dev/null for a cleaner log. Remove > /dev/null to see full build logs.
  xcodebuild clean -project "ChaosCanary.xcodeproj" -scheme "ChaosCanary" > /dev/null
  # Build unsigned: no Apple Developer account needed.
  # Sauce Labs automatically re-signs the app for its real devices.
  xcodebuild build-for-testing \
   -project "ChaosCanary.xcodeproj" \
   -scheme "ChaosCanary" \
   -sdk iphoneos \
   -destination "generic/platform=iOS" \
   -derivedDataPath "build" \
   CODE_SIGNING_ALLOWED=NO > /dev/null
  echo "--- Build Complete ---"
else
  echo "--- Skipping build. Using existing artifacts. ---"
fi

# --- 3. Run the Selected Test(s) on Sauce Labs ---
run_test() {
    local type=$1
    local config_file=".sauce/config.$type.yml"
    # Use 'tr' for a more compatible way to convert to uppercase.
    local type_upper=$(echo "$type" | tr '[:lower:]' '[:upper:]')
    echo "--- Starting Sauce Labs Test Run: ${type_upper} ---"
    saucectl run -c "$config_file"
}

case $TEST_TYPE in
  normal|failure|latency|random)
    run_test "$TEST_TYPE"
    ;;
  all)
    echo "--- Starting All Sauce Labs Test Runs ---"
    run_test "normal"
    run_test "failure"
    run_test "latency"
    run_test "random"
    ;;
  *)
    echo "Error: Invalid test type '$TEST_TYPE'."
    echo "Usage: $0 {normal|failure|latency|random|all} [--rebuild]"
    exit 1
    ;;
esac

echo "--- Script Finished Successfully ---"

