#!/usr/bin/env bash
#
# demo_sauce.sh — Full-stack demo: chaos proxies + Sauce Connect tunnels
#                 + XCUITests on a real device in the Sauce Labs cloud.
#
# This is the "money shot" act: a real iPhone in Sauce's data center runs
# the ChaosCanary UI tests while the device's traffic is routed back
# through your local mitmproxy, which sabotages it live.
#
# Prerequisites (checked by this script):
#   1. Docker Desktop running
#   2. .env with SAUCE_USERNAME / SAUCE_ACCESS_KEY / SAUCE_REGION
#      (copy .env.example and fill it in)
#   3. saucectl installed and on PATH
#   4. The app + test runner built into ./build
#      (xcodebuild build-for-testing ... — see demo guide or
#       run_chaos_test.sh --rebuild)
#
# Usage:
#   demo/demo_sauce.sh {normal|failure|latency|random|all} [--rebuild]
#
set -euo pipefail

MODE="${1:-}"
case "$MODE" in
  normal|failure|latency|random|all) ;;
  *)
    echo "Usage: $0 {normal|failure|latency|random|all} [--rebuild]"
    exit 1
    ;;
esac
EXTRA_FLAGS="${2:-}"

# --- Resolve the project root (this script lives in demo/) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_ROOT"

if docker compose version > /dev/null 2>&1; then
  COMPOSE="docker compose"
else
  COMPOSE="docker-compose"
fi

banner() {
  echo ""
  echo "=================================================================="
  echo "  $1"
  echo "=================================================================="
}

# --- 1. Preflight ----------------------------------------------------------
banner "Preflight checks"
docker info > /dev/null 2>&1 || { echo "ERROR: Docker is not running."; exit 1; }
command -v saucectl > /dev/null 2>&1 || { echo "ERROR: saucectl not found on PATH."; exit 1; }

if [ ! -f .env ]; then
  echo "ERROR: .env not found."
  echo "  cp .env.example .env   # then fill in your Sauce Labs credentials"
  exit 1
fi
set -a; source ./.env; set +a
: "${SAUCE_USERNAME:?SAUCE_USERNAME is missing from .env}"
: "${SAUCE_ACCESS_KEY:?SAUCE_ACCESS_KEY is missing from .env}"
: "${SAUCE_REGION:?SAUCE_REGION is missing from .env}"
if [ "$SAUCE_USERNAME" = "your-sauce-username" ] || [ "$SAUCE_ACCESS_KEY" = "your-sauce-access-key" ]; then
  echo "ERROR: .env still contains the placeholder credentials from .env.example."
  echo "Edit .env with your real Sauce Labs credentials, found at:"
  echo "  https://app.saucelabs.com/user-settings  (Username and Access Key)"
  exit 1
fi
echo "Sauce user:   ${SAUCE_USERNAME}"
echo "Sauce region: ${SAUCE_REGION}"

# --- 2. Build (only if asked or artifacts are missing) ----------------------
APP_PATH="build/Build/Products/Debug-iphoneos/ChaosCanary.app"
RUNNER_PATH="build/Build/Products/Debug-iphoneos/ChaosCanaryUITests-Runner.app"
if [ "$EXTRA_FLAGS" = "--rebuild" ] || [ ! -d "$APP_PATH" ] || [ ! -d "$RUNNER_PATH" ]; then
  banner "Building the iOS app + test runner (this takes a few minutes)"
  # Build unsigned: no Apple Developer account needed.
  # Sauce Labs automatically re-signs the app for its real devices.
  xcodebuild build-for-testing \
    -project "ChaosCanary.xcodeproj" \
    -scheme "ChaosCanary" \
    -sdk iphoneos \
    -destination "generic/platform=iOS" \
    -derivedDataPath "build" \
    CODE_SIGNING_ALLOWED=NO
else
  echo "Using existing build artifacts in ./build (pass --rebuild to force)."
fi

# --- 3. Bring up the full stack ---------------------------------------------
banner "Starting proxies + Sauce Connect tunnels"
${COMPOSE} up -d

# Wait for the tunnel(s) the requested mode actually needs.
wait_for_tunnel() {
  local name=$1
  local tries=0
  echo "Waiting for tunnel '${name}'..."
  until ${COMPOSE} logs "tunnel-${name}" 2>/dev/null | grep -q "Sauce Connect is up"; do
    tries=$((tries + 1))
    # Fail fast if the tunnel container died (e.g. bad credentials).
    if [ -z "$(${COMPOSE} ps --status running -q "tunnel-${name}" 2>/dev/null)" ]; then
      echo "ERROR: tunnel-${name} exited before coming up. Recent logs:"
      ${COMPOSE} logs --tail 10 "tunnel-${name}"
      echo ""
      echo "Most common cause: bad credentials in .env"
      exit 1
    fi
    if [ "$tries" -gt 120 ]; then
      echo "ERROR: tunnel-${name} did not come up within 2 minutes."
      echo "Inspect with: ${COMPOSE} logs tunnel-${name}"
      exit 1
    fi
    sleep 1
  done
  echo "  tunnel-${name} is up."
}

if [ "$MODE" = "all" ]; then
  for m in normal failure latency random-failure; do wait_for_tunnel "$m"; done
else
  # compose service for 'random' is tunnel-random-failure
  [ "$MODE" = "random" ] && MODE_SERVICE="random-failure" || MODE_SERVICE="$MODE"
  wait_for_tunnel "$MODE_SERVICE"
fi

# --- 4. Run the tests --------------------------------------------------------
banner "Running saucectl: mode = ${MODE}"
echo "Watch live in the Sauce Labs dashboard, and the traffic in mitmweb:"
echo "  normal:  http://localhost:8085   failure: http://localhost:8081"
echo "  latency: http://localhost:8083   random:  http://localhost:8087"
./run_chaos_test.sh "$MODE"

banner "Full-stack demo complete"
echo "The stack is still up for audience Q&A. Tear down with:"
echo "  ${COMPOSE} down"
