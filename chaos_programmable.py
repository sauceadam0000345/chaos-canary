# chaos_programmable.py
import os
import time
import random
from mitmproxy import http
from mitmproxy import ctx

# --- Read General Configuration ---
CHAOS_MODE = os.environ.get('CHAOS_MODE', 'NONE').upper()
CHAOS_TARGET_API = os.environ.get('CHAOS_TARGET_API')

# --- Read Latency Mode Configuration ---
CHAOS_DELAY_SECONDS = float(os.environ.get('CHAOS_DELAY_SECONDS', 0))

# --- Read API Failure Mode Configuration ---
CHAOS_HTTP_CODE = int(os.environ.get('CHAOS_HTTP_CODE', 500))

# --- Read NEW Random Failure Mode Configuration ---
CHAOS_FAILURE_RATE = float(os.environ.get('CHAOS_FAILURE_RATE', 0.0))
CHAOS_FAILURE_CODES_STR = os.environ.get('CHAOS_FAILURE_CODES', "500,502,503")
CHAOS_FAILURE_CODES = [int(code) for code in CHAOS_FAILURE_CODES_STR.split(',')]
CHAOS_TIMEOUT_RATE = float(os.environ.get('CHAOS_TIMEOUT_RATE', 0.0))
CHAOS_TIMEOUT_SECONDS = float(os.environ.get('CHAOS_TIMEOUT_SECONDS', 30.0))


def request(flow: http.HTTPFlow) -> None:
    """This function is called for every HTTP request."""
    if CHAOS_TARGET_API and CHAOS_TARGET_API in flow.request.pretty_url:
        if CHAOS_MODE == 'LATENCY':
            ctx.log.info(f"CHAOS: Delaying request by {CHAOS_DELAY_SECONDS} seconds...")
            time.sleep(CHAOS_DELAY_SECONDS)

def response(flow: http.HTTPFlow) -> None:
    """This function is called for every HTTP response."""
    # Don't interfere with traffic that's already an error.
    if flow.response.status_code >= 400:
        return

    if CHAOS_TARGET_API and CHAOS_TARGET_API in flow.request.pretty_url:
        if CHAOS_MODE == 'API_FAILURE':
            ctx.log.info(f"CHAOS: Forcing failure with status {CHAOS_HTTP_CODE}")
            flow.response.status_code = CHAOS_HTTP_CODE
            flow.response.text = "CHAOS: Service unavailable as per chaos script."

        elif CHAOS_MODE == 'RANDOM_FAILURE':
            # Decide if this request should fail based on the failure rate.
            if random.random() < CHAOS_FAILURE_RATE:
                # Decide if this failure should be a timeout or an error code.
                if random.random() < CHAOS_TIMEOUT_RATE:
                    ctx.log.info(f"CHAOS: Injecting a {CHAOS_TIMEOUT_SECONDS}s timeout...")
                    time.sleep(CHAOS_TIMEOUT_SECONDS)
                else:
                    # Pick a random error code from our list.
                    random_code = random.choice(CHAOS_FAILURE_CODES)
                    ctx.log.info(f"CHAOS: Injecting random failure with status {random_code}")
                    flow.response.status_code = random_code
                    flow.response.text = f"CHAOS: Random failure injected."

def load(loader):
    ctx.log.info("--- Programmable Chaos Script Loaded ---")
    ctx.log.info(f"CHAOS_MODE: {CHAOS_MODE}")
    if CHAOS_TARGET_API:
        ctx.log.info(f"CHAOS_TARGET_API: {CHAOS_TARGET_API}")
    # ... Log other mode-specific variables ...
    ctx.log.info("--------------------------------------")


