# Chaos Canary 🧪🐦

A self-contained, Dockerized environment for performing chaos testing on native iOS applications using Sauce Labs, `saucectl`, Sauce Connect, and a programmable `mitmproxy` instance.

This project serves as a minimal, reproducible example for intercepting and manipulating network traffic from a real device test running in the Sauce Labs cloud.

---

## Features

- **Containerized Environment:** The entire tunnel and proxy stack is managed by Docker Compose. Start and stop everything with a single command.
- **Programmable Chaos:** Inject API failures or latency on the fly by setting environment variables.
- **Real Device Testing:** Designed to work with the Sauce Labs Real Device Cloud.
- **Clean & Isolated:** The Docker setup is independent of your local machine's network or DNS configuration.

---

## Prerequisites

Before you begin, ensure you have the following tools installed on your macOS machine:

- **Git:** For cloning the repository.
- **Xcode Command Line Tools:** For building the iOS app.
- **Docker Desktop:** For running the containerized environment.
- **`saucectl`:** The [Sauce Labs command-line](https://docs.saucelabs.com/dev/cli/saucectl/) test orchestrator.

> **_NOTE:_** This project assumes you have proper Sauce Labs credentials configured according to the documentation.

---

## Setup Instructions

**1. Clone the Repository**

```bash
git clone git@github.com:mmerrell/chaos-canary.git
cd chaos-canary
```

**2. Configure Your Credentials**

This project uses an `.env` file to manage your Sauce Labs credentials and tunnel configuration securely.

-   Create a copy of the example file:
    ```bash
    cp .env.example .env
    ```
-   Edit the new `.env` file and replace the placeholder values with your actual Sauce Labs username, access key, and desired region.

**3. Build the iOS App**

The first time you set up the project, you need to compile the `ChaosCanary` app and its test runner. Run the following command from the project root:

```bash
xcodebuild build-for-testing \
 -project "ChaosCanary.xcodeproj" \
 -scheme "ChaosCanary" \
 -sdk iphoneos \
 -destination "generic/platform=iOS" \
 -derivedDataPath "build" \
 -allowProvisioningUpdates
```

---

## Running the Environment

**Starting the Services**

This command will build the Docker image (the first time) and start the `mitmproxy` and Sauce Connect containers.

```bash
docker-compose up --build
```

For subsequent runs, you can omit the `--build` flag:
```bash
docker-compose up
```

Wait for the logs to show `Sauce Connect is up, you may start your tests`.

**Stopping the Services**

To stop the containers cleanly, press `Ctrl+C` in the terminal where they are running, and then run:

```bash
docker-compose down
```

---

## Executing the example Tests

With the Docker environment running, open a **new terminal window** in the project directory and run your tests using `run_chaos_test.sh`:

```bash
./run_chaos_test.sh all
```

You can run the tests in 4 separate modes:
* normal - runs with a proxy, but with no interference or interception of the requests. You can still view and track HTTP calls within the proxy (via http://localhost:8081).
* failure - runs with a proxy that will return failed status codes for all HTTP traffic emitted by the app. You can inspect these HTTP requests at http://localhost:8083.
* latency - runs with a proxy that inserts an arbitrary 5-second wait before returning the response. It does not alter the response in any way. HTTP traffic for this proxy is at http://localhost:8085.
* random - runs with a proxy which is set to return random failures whenever an HTTP request is made. This HTTP traffic is available for inspection at http://localhost:8087. 
* all - runs all tests against all proxies. This is done serially, not in parallel, due to the nature of saucectl's config schema. All above proxies will show HTTP traffic.

```bash 
    ✗ ./run_chaos_test.sh        
    Error: No test type specified.
    Usage: ./run_chaos_test.sh {normal|failure|latency|random|all} [--rebuild]
```

You can monitor the intercepted network traffic by opening a browser and navigating to the `mitmweb` interface at **`http://localhost:8081`**.

Note that running `saucectl run` on its own in this folder will not work, as there is no single config.yml file. The `run_chaos_test.sh` script was specially formulated to demonstrate the various chaos modes available.

---

## How to Inject Chaos

You can control the chaos script running inside the `mitmproxy` container by setting environment variables in your terminal **before** you run `docker-compose up`.

### Example 1: Inject Latency

This will make any request containing `todos/1` take an extra 5 seconds.

```bash
export CHAOS_MODE="LATENCY"
export CHAOS_TARGET_API="todos/1"
export CHAOS_DELAY_SECONDS="5"

docker-compose up
```

### Example 2: Inject an API Failure

This will force any request containing `todos/1` to fail with a `503 Service Unavailable` error.

```bash
export CHAOS_MODE="API_FAILURE"
export CHAOS_TARGET_API="todos/1"
export CHAOS_HTTP_CODE="503"

docker-compose up
```

### Injecting Random Chaos

You can configure two types of chaos in "random" mode: timeouts and failures. These are configurable as percentage changes and set as environment variables within the docker-compose files.

#### CHAOS_FAILURE_RATE

    With this setting, the proxy will roll the dice on any HTTP Request (or on a specific one if used with CHAOS_TARGET_API) to either the response back normally, or to return a failure rate.

#### CHAOS_TIMEOUT_RATE

    This setting lets you add a random 30-second response time to an HTTP request. `mitmproxy` will roll the dice at runtime for each request.

Setting either field to 0.00 will make the proxy exhibit "normal" behavior for the given feature. These features can be used at the same time to inject both kinds of chaos!

#### Within docker-compose.yml:

```yaml
    environment:
      # Hardcode this proxy to be in RANDOM_FAILURE mode.
      - CHAOS_MODE=RANDOM_FAILURE
      - CHAOS_TARGET_API=todos/1 # Omit this line to apply chaos to any HTTP Request
      # 25% chance of any given request failing.
      - CHAOS_FAILURE_RATE=0.25
      # Possible error codes to return.
      - CHAOS_FAILURE_CODES=404,500,502,503
      # Of the requests that fail, 10% will be timeouts instead of error codes.
      - CHAOS_TIMEOUT_RATE=0.10
      - CHAOS_TIMEOUT_SECONDS=30
```

### Running a "Happy Path" Test

To run a normal test with no chaos, simply unset the environment variables or set `CHAOS_MODE` to `NONE`.

```bash
export CHAOS_MODE="NONE"
docker-compose up
```

---

## Project Structure

-   **`Dockerfile`**: The recipe for building the container image with Python, `mitmproxy`, and Sauce Connect.
-   **`docker-compose.yml`**: Orchestrates the `proxy` and `tunnel` services.
-   **`chaos_programmable.py`**: The Python script that `mitmproxy` uses to inject chaos.
-   **`.env`**: Your secret credentials and tunnel configuration.
-   **`.sauce/config.yml`**: The configuration for `saucectl` to run the tests.
-   **`ChaosCanary/`**: The minimal Xcode project for the iOS app under test.

