# security_scanner.py
import json
import os
import time
import glob
from pathlib import Path
from zapv2 import ZAPv2
from datetime import datetime
import requests


class SecurityScanner:
    def __init__(self):
        self.zap_host = os.getenv('ZAP_HOST', 'localhost')
        self.zap_port = os.getenv('ZAP_PORT', '8090')
        self.zap = ZAPv2(proxies={
            'http': f"http://{self.zap_host}:{self.zap_port}",
            'https': f"http://{self.zap_host}:{self.zap_port}"
        })
        self.results_dir = Path("/app/results")
        self.flows_dir = Path("/app/flows")

        # Ensure results directory exists
        self.results_dir.mkdir(exist_ok=True)

    def wait_for_zap_startup(self):
        """Wait for ZAP to be ready"""
        print("Waiting for ZAP to start...")
        max_attempts = 30
        for attempt in range(max_attempts):
            try:
                # Test ZAP connection
                response = requests.get(f"http://{self.zap_host}:{self.zap_port}")
                if response.status_code == 200:
                    print("ZAP is ready!")
                    return True
            except requests.RequestException:
                pass

            print(f"Attempt {attempt + 1}/{max_attempts} - ZAP not ready yet...")
            time.sleep(5)

        raise TimeoutError("ZAP failed to start within timeout period")

    def wait_for_flows(self):
        """Wait for flow files to appear from chaos testing"""
        print("Waiting for recorded flows from chaos testing...")

        timeout = 600  # 10 minutes
        start_time = time.time()

        while time.time() - start_time < timeout:
            flow_files = list(self.flows_dir.glob("*.json"))
            # Filter out summary files
            flow_files = [f for f in flow_files if not f.name.startswith('summary_')]

            if flow_files:
                print(f"Found {len(flow_files)} flow files!")
                # Wait a bit more to ensure files are complete
                time.sleep(10)
                return flow_files

            print("No flow files found yet, waiting...")
            time.sleep(10)

        # If no flows found, that's ok - maybe no traffic was generated
        print("No flow files found, proceeding without recorded flows")
        return []

    def scan_recorded_flows(self):
        """Main method to scan all recorded flows"""
        try:
            # Wait for ZAP to be ready
            self.wait_for_zap_startup()

            # Wait for flow files
            flow_files = self.wait_for_flows()

            if not flow_files:
                print("No flows to analyze, exiting")
                return

            print(f"Starting security analysis of {len(flow_files)} flow files")

            for flow_file in flow_files:
                self.scan_single_flow_file(flow_file)

            print("Security scanning complete!")

        except Exception as e:
            print(f"Error in security scanning: {e}")
            raise

    def scan_single_flow_file(self, flow_file: Path):
        """Scan a single flow file"""
        print(f"\\n--- Analyzing {flow_file.name} ---")

        try:
            with open(flow_file) as f:
                flows = json.load(f)
        except json.JSONDecodeError as e:
            print(f"Error reading {flow_file}: {e}")
            return

        if not flows:
            print(f"No flows found in {flow_file}")
            return

        # Extract chaos mode from flows
        chaos_mode = flows[0].get('chaos_mode', 'UNKNOWN')
        print(f"Processing {len(flows)} flows for chaos mode: {chaos_mode}")

        # Extract unique target URLs
        target_urls = self.extract_target_urls(flows)
        print(f"Target URLs: {target_urls}")

        if not target_urls:
            print("No valid target URLs found")
            return

        # Step 1: Spider the targets to discover pages
        for url in target_urls:
            print(f"Spidering {url}...")
            try:
                spider_id = self.zap.spider.scan(url)
                self.wait_for_spider_completion(spider_id)
                print(f"Spider completed for {url}")
            except Exception as e:
                print(f"Error spidering {url}: {e}")

        # Step 2: Feed recorded requests to ZAP
        print("Feeding recorded requests to ZAP...")
        successful_requests = 0

        for i, flow in enumerate(flows):
            try:
                if flow['method'] in ['GET', 'POST', 'PUT', 'DELETE', 'PATCH']:
                    # Send request to ZAP for analysis
                    self.send_request_to_zap(flow)
                    successful_requests += 1

                    if (i + 1) % 10 == 0:
                        print(f"Processed {i + 1}/{len(flows)} requests")

            except Exception as e:
                print(f"Error processing request {i}: {e}")
                continue

        print(f"Successfully sent {successful_requests}/{len(flows)} requests to ZAP")

        # Step 3: Run active security scan
        print("Starting active security scan...")
        for url in target_urls:
            try:
                scan_id = self.zap.ascan.scan(url)
                self.wait_for_scan_completion(scan_id)
                print(f"Active scan completed for {url}")
            except Exception as e:
                print(f"Error scanning {url}: {e}")

        # Step 4: Save results
        self.save_scan_results(chaos_mode, target_urls, flow_file.stem)

    def extract_target_urls(self, flows):
        """Extract unique base URLs from flows"""
        urls = set()
        for flow in flows:
            if flow.get('url'):
                try:
                    from urllib.parse import urlparse
                    parsed = urlparse(flow['url'])
                    if parsed.scheme and parsed.netloc:
                        base_url = f"{parsed.scheme}://{parsed.netloc}"
                        urls.add(base_url)
                except Exception as e:
                    print(f"Error parsing URL {flow.get('url')}: {e}")
        return list(urls)

    def send_request_to_zap(self, flow):
        """Send a recorded request to ZAP"""
        try:
            method = flow['method']
            url = flow['url']
            content = flow.get('content', '')

            if method == 'GET':
                self.zap.core.send_request(url)
            elif method in ['POST', 'PUT', 'PATCH']:
                self.zap.core.send_request(url, method=method, body=content or '')
            else:
                self.zap.core.send_request(url, method=method)

        except Exception as e:
            # Don't log every error, just count them
            pass

    def wait_for_spider_completion(self, spider_id):
        """Wait for spider completion"""
        while int(self.zap.spider.status(spider_id)) < 100:
            time.sleep(2)

    def wait_for_scan_completion(self, scan_id):
        """Wait for active scan completion"""
        while int(self.zap.ascan.status(scan_id)) < 100:
            progress = self.zap.ascan.status(scan_id)
            print(f"Scan progress: {progress}%")
            time.sleep(5)

    def save_scan_results(self, chaos_mode, target_urls, file_stem):
        """Save ZAP scan results"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

        try:
            # Get all alerts
            alerts = self.zap.core.alerts()

            # Categorize alerts by risk level
            risk_counts = {'High': 0, 'Medium': 0, 'Low': 0, 'Informational': 0}
            for alert in alerts:
                risk = alert.get('risk', 'Low')
                risk_counts[risk] = risk_counts.get(risk, 0) + 1

            # Create summary
            summary = {
                'chaos_mode': chaos_mode,
                'target_urls': target_urls,
                'scan_timestamp': timestamp,
                'total_alerts': len(alerts),
                'risk_breakdown': risk_counts,
                'alerts': alerts
            }

            # Save detailed results
            results_file = self.results_dir / f"security_scan_{chaos_mode}_{timestamp}.json"
            with open(results_file, 'w') as f:
                json.dump(summary, f, indent=2)

            # Save human-readable summary
            summary_file = self.results_dir / f"summary_{chaos_mode}_{timestamp}.txt"
            with open(summary_file, 'w') as f:
                f.write(f"Security Scan Summary - {chaos_mode}\\n")
                f.write(f"{'=' * 50}\\n")
                f.write(f"Scan Date: {timestamp}\\n")
                f.write(f"Target URLs: {', '.join(target_urls)}\\n")
                f.write(f"Total Alerts: {len(alerts)}\\n\\n")
                f.write("Risk Breakdown:\\n")
                for risk, count in risk_counts.items():
                    f.write(f"  {risk}: {count}\\n")

                if alerts:
                    f.write(f"\\nTop Issues:\\n")
                    for alert in alerts[:10]:  # Top 10 issues
                        f.write(f"  - {alert.get('name', 'Unknown')}: {alert.get('risk', 'Unknown')} risk\\n")

            print(f"Results saved:")
            print(f"  Detailed: {results_file}")
            print(f"  Summary: {summary_file}")
            print(
                f"  Found {len(alerts)} security issues ({risk_counts['High']} high, {risk_counts['Medium']} medium risk)")

        except Exception as e:
            print(f"Error saving scan results: {e}")


if __name__ == "__main__":
    scanner = SecurityScanner()
    scanner.scan_recorded_flows()