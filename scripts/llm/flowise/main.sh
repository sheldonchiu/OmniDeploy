#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Flowise ###"
log "Setting up Flowise"
if [[ "$REINSTALL_FLOWISE" || ! -f "/tmp/flowise.prepared" ]]; then

    
    rm -rf $VENV_DIR/flowise-env
    
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - &&\
    apt-get install -y nodejs

    npm install -g flowise
    
    touch /tmp/flowise.prepared
else
    
    log "Environment already prepared"
    
fi
log "Finished Preparing Environment for Flowise"





if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Flowise ###"
  log "Starting Flowise"
  PORT=$FLOWISE_PORT service_loop "npx flowise start" > $LOG_DIR/flowise.log 2>&1 &
  echo $! > /tmp/flowise.pid
fi


send_to_discord "Flowise Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/flowise/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"flowise"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,flowise"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"