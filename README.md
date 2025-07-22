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
- **`saucectl`:** The Sauce Labs command-line test orchestrator.

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

## Executing a Test

With the Docker environment running, open a **new terminal window** in the project directory and run your tests using `saucectl`:

```bash
saucectl run
```

You can monitor the intercepted network traffic by opening a browser and navigating to the `mitmweb` interface at **`http://localhost:8081`**.

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

