#!/bin/bash
# docker run -it --rm -v /root:/data -p 8888:8888 -v /mnt/data/OmniDeploy:/workspace --gpus all omnideploy /bin/bash -c "apt-get -qq update && apt-get install -y curl > /dev/null && curl -s https://raw.githubusercontent.com/sheldonxxxx/OmniDeploy/refs/heads/dev/init.sh | bash && /bin/bash"
set -e

# Update and install dependencies with reduced verbosity
apt-get update -qq
apt-get install -y git > /dev/null

# Set default working directory if not defined
WORKING_DIR=${WORKING_DIR:-"/workspace"}
mkdir -p "$WORKING_DIR"

# Clone and run OmniDeploy
cd "$WORKING_DIR"
if [[ ! -d "OmniDeploy" ]]; then
  git clone -q https://github.com/sheldonxxxx/OmniDeploy.git > /dev/null
  git checkout dev
fi
cd "$WORKING_DIR/OmniDeploy"
git pull -q origin dev > /dev/null
bash entry.sh
