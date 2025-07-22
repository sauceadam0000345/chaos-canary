# Use an official Python runtime as a parent image
FROM python:3.11-slim

# Set environment variables to prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary tools: curl and unzip
RUN apt-get update && apt-get install -y curl unzip && rm -rf /var/lib/apt/lists/*

# Install mitmproxy using pip
RUN pip install mitmproxy

# --- Install Sauce Connect Proxy ---
# Set Sauce Connect version and download URL
ARG SC_VERSION=5.3.0
ARG SC_PLATFORM=linux.x86_64
ARG SC_URL=https://saucelabs.com/downloads/sauce-connect/${SC_VERSION}/sauce-connect-${SC_VERSION}_${SC_PLATFORM}.tar.gz

# Download, create the destination folder, extract directly into it, and clean up.
# This is more robust than assuming the extracted folder name.
RUN curl -L $SC_URL -o sc.tar.gz && \
    mkdir -p /sauceconnect && \
    tar -xzf sc.tar.gz -C /sauceconnect && \
    rm sc.tar.gz

# Add the Sauce Connect binary to the system's PATH
ENV PATH="/sauceconnect:${PATH}"

# Set the working directory inside the container
WORKDIR /app

# Copy your chaos script into the container's working directory
COPY chaos_programmable.py .

# Expose the ports for mitmproxy's web UI and proxy server
EXPOSE 8081 8082

