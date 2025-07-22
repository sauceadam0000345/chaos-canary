#!/bin/bash

# This script automates the process of cleaning, building, and running
# the ChaosCanary tests on Sauce Labs.
#
# It's designed to be run from the root of the ChaosCanary project directory.

# Exit immediately if any command fails.
set -e

# --- 1. Clean the Project ---
echo "--- Cleaning Xcode Project ---"
xcodebuild clean \
 -project "ChaosCanary.xcodeproj" \
 -scheme "ChaosCanary"

# --- 2. Build the App for Testing ---
echo "--- Building App for Testing ---"
xcodebuild build-for-testing \
 -project "ChaosCanary.xcodeproj" \
 -scheme "ChaosCanary" \
 -sdk iphoneos \
 -destination "generic/platform=iOS" \
 -derivedDataPath "build" \
 -allowProvisioningUpdates

# --- 3. Run the Tests on Sauce Labs ---
echo "--- Starting Sauce Labs Test Run ---"
saucectl run

echo "--- Script Finished Successfully ---"

