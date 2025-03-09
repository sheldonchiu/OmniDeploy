#!/bin/bash
# apt-get -qq update && apt-get install -y curl > /dev/null && curl -s https://raw.githubusercontent.com/sheldonchiu/OmniDeploy/refs/heads/dev/init.sh | bash
set -e

# Update and install dependencies with reduced verbosity
apt-get update -qq
apt-get install -y git > /dev/null

# Set default working directory if not defined
WORKING_DIR=${WORKING_DIR:-"/workspace"}
mkdir -p "$WORKING_DIR"

# Clone and run OmniDeploy
cd "$WORKING_DIR"
git clone https://github.com/sheldonchiu/OmniDeploy.git
cd "$WORKING_DIR/OmniDeploy"
git checkout dev
bash entry.sh
