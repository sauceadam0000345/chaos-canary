# chaos_programmable.py
import os
import time
import random
import json
from datetime import datetime
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

# --- NEW: Flow Recording Configuration ---
RECORD_FLOWS = os.environ.get('RECORD_FLOWS', 'true').lower() == 'true'
FLOWS_OUTPUT_DIR = os.environ.get('FLOWS_OUTPUT_DIR', '/app/flows')

# Global list to store recorded flows
recorded_flows = []


def request(flow: http.HTTPFlow) -> None:
    """This function is called for every HTTP request."""
    if CHAOS_TARGET_API and CHAOS_TARGET_API in flow.request.pretty_url:
        if CHAOS_MODE == 'LATENCY':
            ctx.log.info(f"CHAOS: Delaying request by {CHAOS_DELAY_SECONDS} seconds...")
            time.sleep(CHAOS_DELAY_SECONDS)


def response(flow: http.HTTPFlow) -> None:
    """This function is called for every HTTP response."""

    # NEW: Record flow for security analysis BEFORE chaos modifications
    if RECORD_FLOWS:
        record_flow_for_security(flow)

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


def record_flow_for_security(flow: http.HTTPFlow) -> None:
    """NEW: Record HTTP flow for later security analysis"""
    try:
        # Decode content safely
        request_content = None
        if flow.request.content:
            try:
                request_content = flow.request.content.decode('utf-8')
            except UnicodeDecodeError:
                request_content = f"<binary data: {len(flow.request.content)} bytes>"

        response_content = None
        if flow.response and flow.response.content:
            try:
                response_content = flow.response.content.decode('utf-8')
            except UnicodeDecodeError:
                response_content = f"<binary data: {len(flow.response.content)} bytes>"

        recorded_flow = {
            'timestamp': datetime.now().isoformat(),
            'chaos_mode': CHAOS_MODE,
            'url': flow.request.pretty_url,
            'method': flow.request.method,
            'headers': dict(flow.request.headers),
            'content': request_content,
            'response_status': flow.response.status_code if flow.response else None,
            'response_headers': dict(flow.response.headers) if flow.response else None,
            'response_content': response_content,
            'target_api_matched': CHAOS_TARGET_API in flow.request.pretty_url if CHAOS_TARGET_API else False
        }

        recorded_flows.append(recorded_flow)

        # Log every 10 flows to track progress
        if len(recorded_flows) % 10 == 0:
            ctx.log.info(f"SECURITY: Recorded {len(recorded_flows)} flows for analysis")

    except Exception as e:
        ctx.log.error(f"Error recording flow for security analysis: {e}")


def save_recorded_flows() -> None:
    """NEW: Save recorded flows to file for ZAP analysis"""
    if not recorded_flows or not RECORD_FLOWS:
        return

    try:
        # Create output directory
        os.makedirs(FLOWS_OUTPUT_DIR, exist_ok=True)

        # Generate filename with timestamp and chaos mode
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"flows_{CHAOS_MODE}_{timestamp}.json"
        filepath = os.path.join(FLOWS_OUTPUT_DIR, filename)

        # Save flows to JSON file
        with open(filepath, 'w') as f:
            json.dump(recorded_flows, f, indent=2)

        ctx.log.info(f"SECURITY: Saved {len(recorded_flows)} flows to {filepath}")

        # Also save a summary file
        summary = {
            'chaos_mode': CHAOS_MODE,
            'total_flows': len(recorded_flows),
            'target_api': CHAOS_TARGET_API,
            'timestamp': timestamp,
            'unique_urls': len(set(flow['url'] for flow in recorded_flows)),
            'http_methods': list(set(flow['method'] for flow in recorded_flows)),
            'status_codes': list(set(flow['response_status'] for flow in recorded_flows if flow['response_status']))
        }

        summary_file = os.path.join(FLOWS_OUTPUT_DIR, f"summary_{CHAOS_MODE}_{timestamp}.json")
        with open(summary_file, 'w') as f:
            json.dump(summary, f, indent=2)

        ctx.log.info(f"SECURITY: Flow summary saved to {summary_file}")

    except Exception as e:
        ctx.log.error(f"Error saving recorded flows: {e}")


def done() -> None:
    """NEW: Called when mitmproxy shuts down - save recorded flows"""
    if RECORD_FLOWS:
        ctx.log.info("SECURITY: Saving recorded flows for security analysis...")
        save_recorded_flows()


def load(loader):
    ctx.log.info("--- Programmable Chaos Script Loaded ---")
    ctx.log.info(f"CHAOS_MODE: {CHAOS_MODE}")
    if CHAOS_TARGET_API:
        ctx.log.info(f"CHAOS_TARGET_API: {CHAOS_TARGET_API}")
    ctx.log.info(f"RECORD_FLOWS: {RECORD_FLOWS}")
    if RECORD_FLOWS:
        ctx.log.info(f"FLOWS_OUTPUT_DIR: {FLOWS_OUTPUT_DIR}")
    ctx.log.info("--------------------------------------")