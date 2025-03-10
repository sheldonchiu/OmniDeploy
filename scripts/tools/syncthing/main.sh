#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Syncthing ###"
log "Setting up Syncthing"
if [[ "$REINSTALL_SYNCTHING" || ! -f "/tmp/syncthing.prepared" ]]; then

    
    rm -rf $VENV_DIR/syncthing-env
    
    cd $VENV_DIR/bin
    curl -L https://github.com/syncthing/syncthing/releases/download/v1.29.2/syncthing-linux-amd64-v1.29.2.tar.gz | tar -xz
    
    touch /tmp/syncthing.prepared
else
    
    log "Environment already prepared"
    
fi
log "Finished Preparing Environment for Syncthing"





if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Syncthing ###"
  log "Starting Syncthing"
  $VENV_DIR/bin/syncthing --no-browser --home $ROOT_REPO_DIR/settings/syncthing --gui-address=0.0.0.0:7019
fi


send_to_discord "Syncthing Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/syncthing/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"syncthing"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,syncthing"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"