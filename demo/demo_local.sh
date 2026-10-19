#!/usr/bin/env bash
#
# demo_local.sh — Narrated local demo of the chaos proxies.
#
# This act of the demo needs NO Sauce Labs account and NO iOS build.
# It starts only the four mitmproxy containers (no tunnels) and drives
# traffic through each one with curl so the audience can see each chaos
# mode in action, live, in seconds.
#
# Usage:
#   demo/demo_local.sh              Run the full narrated demo
#   demo/demo_local.sh --cleanup    Tear the proxy containers down at the end
#   demo/demo_local.sh --no-open    Don't open the mitmweb UIs in the browser
#
# Override the target API if you want to demo against something else:
#   TARGET_URL="https://httpbin.org/get" demo/demo_local.sh
#
set -euo pipefail

TARGET_URL="${TARGET_URL:-https://jsonplaceholder.typicode.com/todos/1}"
CLEANUP=false
OPEN_UI=true
for arg in "$@"; do
  case $arg in
    --cleanup) CLEANUP=true ;;
    --no-open) OPEN_UI=false ;;
    *) echo "Unknown argument: $arg"; echo "Usage: $0 [--cleanup] [--no-open]"; exit 1 ;;
  esac
done

# --- Resolve the project root (this script lives in demo/) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_ROOT"

# --- Prefer 'docker compose' (v2), fall back to 'docker-compose' (v1) ---
if docker compose version > /dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose > /dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "ERROR: Neither 'docker compose' nor 'docker-compose' was found."
  echo "Install Docker Desktop: https://www.docker.com/products/docker-desktop/"
  exit 1
fi

# --- Service / port map (must match docker-compose.yml) ---
#     mode        service              proxy port   web UI port
MODES=("normal"   "failure"  "latency" "random")
SERVICES=("proxy-normal" "proxy-failure" "proxy-latency" "proxy-random-failure")
PROXY_PORTS=(8086 8082 8084 8088)
WEB_PORTS=(8085 8081 8083 8087)

banner() {
  echo ""
  echo "=================================================================="
  echo "  $1"
  echo "=================================================================="
}

wait_for_ui() {
  local port=$1
  local tries=0
  until curl -s -o /dev/null "http://localhost:${port}"; do
    tries=$((tries + 1))
    if [ "$tries" -gt 60 ]; then
      echo "ERROR: proxy on port ${port} did not come up within 60s."
      echo "Check logs with: ${COMPOSE} logs"
      exit 1
    fi
    sleep 1
  done
}

# --- 0. Preflight --------------------------------------------------------
banner "Preflight checks"
if ! docker info > /dev/null 2>&1; then
  echo "ERROR: Docker is not running. Start Docker Desktop and retry."
  exit 1
fi
echo "Docker is running."
echo "Compose command: ${COMPOSE}"
echo "Target URL:      ${TARGET_URL}"

# --- 1. Start the four proxies -------------------------------------------
banner "Starting the four chaos proxies (no tunnels needed locally)"
${COMPOSE} build --quiet
${COMPOSE} up -d "${SERVICES[@]}"

echo "Waiting for proxies to accept connections..."
for port in 8081 8083 8085 8087; do wait_for_ui "$port"; done
echo "All four proxies are up."

# --- Helper: fire one request through a proxy ----------------------------
fire() {
  local proxy_port=$1
  curl -sk --max-time 60 \
    -x "http://localhost:${proxy_port}" \
    -o /dev/null \
    -w "HTTP %{http_code}   total time: %{time_total}s\n" \
    "$TARGET_URL"
}

# --- 2. NORMAL ------------------------------------------------------------
banner "ACT 1/4: NORMAL proxy (localhost:8086) — traffic passes untouched"
echo "\$ curl -x http://localhost:8086 ${TARGET_URL}"
fire 8086
echo ">> Expected: HTTP 200. This is the 'happy path' baseline."

# --- 3. API FAILURE -------------------------------------------------------
banner "ACT 2/4: FAILURE proxy (localhost:8082) — every matching call returns 503"
echo "\$ curl -x http://localhost:8082 ${TARGET_URL}"
fire 8082
echo ">> Expected: HTTP 503. The proxy rewrote a perfectly good response."
echo ">> Show the audience: the app's 'Failure: 503' label is the UI mirror of this."

# --- 4. LATENCY -----------------------------------------------------------
banner "ACT 3/4: LATENCY proxy (localhost:8084) — 5s delay injected per request"
echo "\$ curl -x http://localhost:8084 ${TARGET_URL}"
echo "(this will feel slow — that IS the demo)"
fire 8084
echo ">> Expected: HTTP 200 but ~5+ seconds. Response is intact, just late."

# --- 5. RANDOM ------------------------------------------------------------
banner "ACT 4/4: RANDOM proxy (localhost:8088) — 25% failures, some 30s timeouts"
echo "Firing 10 requests; watch the status codes vary:"
echo "\$ for i in 1..10: curl -x http://localhost:8088 ${TARGET_URL}"
RANDOM_HITS=0
for i in $(seq 1 10); do
  out=$(fire 8088)
  echo "  request ${i}: ${out}"
  if ! echo "$out" | grep -q "^HTTP 2"; then RANDOM_HITS=$((RANDOM_HITS + 1)); fi
done
echo ">> ${RANDOM_HITS}/10 requests were sabotaged (code or ~30s stall)."
echo ">> 0/10 is possible (0.75^10 ~= 5.6%): re-run the loop if the dice were kind."

# --- 6. Open the web UIs ---------------------------------------------------
if [ "$OPEN_UI" = true ]; then
  banner "Opening the mitmweb UIs — every request above is visible here"
  echo "  normal:  http://localhost:8085"
  echo "  failure: http://localhost:8081"
  echo "  latency: http://localhost:8083"
  echo "  random:  http://localhost:8087"
  for port in 8085 8081 8083 8087; do open "http://localhost:${port}"; done
fi

banner "Local demo complete"
echo "The proxies are still running so you can poke at the mitmweb UIs."
echo ""
echo "Next act (needs Sauce Labs credentials):  demo/demo_sauce.sh all"
echo ""

if [ "$CLEANUP" = true ]; then
  echo "--- --cleanup requested: tearing down proxy containers ---"
  ${COMPOSE} down
  echo "Done."
else
  echo "Tidy up later with:  ${COMPOSE} down   (or demo/demo_local.sh --cleanup)"
fi
