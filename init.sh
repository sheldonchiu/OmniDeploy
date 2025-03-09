#!/bin/bash
set -e

# Update and install dependencies with reduced verbosity
apt-get update -qq
apt-get install -y -qq git

# Set default working directory if not defined
WORKING_DIR=${WORKING_DIR:-"/workspace"}
mkdir -p "$WORKING_DIR"

# Clone and run OmniDeploy
cd "$WORKING_DIR"
git clone https://github.com/sheldonchiu/OmniDeploy.git
cd "$WORKING_DIR/OmniDeploy"
bash entry.sh
