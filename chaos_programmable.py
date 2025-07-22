# chaos_programmable.py
import os
import time
from mitmproxy import http

# Read configuration from Environment Variables
# The 'os.environ.get' function safely gets a variable, using a default if it's not set.
CHAOS_MODE = os.environ.get('CHAOS_MODE', 'NONE').upper()
# Which API endpoint URL fragment to target (e.g., 'v1/login')
CHAOS_TARGET_API = os.environ.get('CHAOS_TARGET_API')
# For API_FAILURE mode, which HTTP status code to return
CHAOS_HTTP_CODE = int(os.environ.get('CHAOS_HTTP_CODE', 500))
# For LATENCY mode, how many seconds to delay
CHAOS_DELAY_SECONDS = float(os.environ.get('CHAOS_DELAY_SECONDS', 0))

def request(flow: http.HTTPFlow) -> None:
    """
    This function is called for every HTTP request before it's sent to the server.
    """
    # Check if a target is defined and if it's in the current request URL
    if CHAOS_TARGET_API and CHAOS_TARGET_API in flow.request.pretty_url:
        if CHAOS_MODE == 'LATENCY':
            print(f"CHAOS: Delaying request to {flow.request.pretty_url} by {CHAOS_DELAY_SECONDS} seconds...")
            time.sleep(CHAOS_DELAY_SECONDS)

def response(flow: http.HTTPFlow) -> None:
    """
    This function is called for every HTTP response before it's sent back to the client.
    """
    # Check if a target is defined and if it's in the current request URL
    if CHAOS_TARGET_API and CHAOS_TARGET_API in flow.request.pretty_url:
        if CHAOS_MODE == 'API_FAILURE':
            print(f"CHAOS: Forcing failure on {flow.request.pretty_url} with status {CHAOS_HTTP_CODE}")
            # Modify the response status code
            flow.response.status_code = CHAOS_HTTP_CODE
            # Overwrite the response body with a custom message
            flow.response.text = f"CHAOS: Service unavailable as per chaos script."

# A simple startup message to confirm the chaos settings when mitmproxy loads the script.
print("--- Programmable Chaos Script Loaded ---")
print(f"CHAOS_MODE: {CHAOS_MODE}")
if CHAOS_TARGET_API:
    print(f"CHAOS_TARGET_API: {CHAOS_TARGET_API}")
    if CHAOS_MODE == 'API_FAILURE':
        print(f"CHAOS_HTTP_CODE: {CHAOS_HTTP_CODE}")
    elif CHAOS_MODE == 'LATENCY':
        print(f"CHAOS_DELAY_SECONDS: {CHAOS_DELAY_SECONDS}")
print("--------------------------------------")

