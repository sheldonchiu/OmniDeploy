#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Langflow ###"
log "Setting up Langflow"
if [[ "$REINSTALL_LANGFLOW" || ! -f "/tmp/langflow.prepared" ]]; then

    
    rm -rf $VENV_DIR/langflow-env
    
    
    python3.10 -m venv $VENV_DIR/langflow-env
    
    source $VENV_DIR/langflow-env/bin/activate

    pip install pip==24.0
    pip install --upgrade wheel setuptools
    
    pip install langflow
    
    touch /tmp/langflow.prepared
else
    
    source $VENV_DIR/langflow-env/bin/activate
    
fi
log "Finished Preparing Environment for Langflow"





if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Langflow ###"
  log "Starting Langflow"
  mkdir -p $REPO_DIR
  cd $REPO_DIR
  PYTHONUNBUFFERED=1 service_loop "python -m langflow --port $LANGFLOW_PORT ${EXTRA_LANGFLOW_ARGS}" > $LOG_DIR/langflow.log 2>&1 &
  echo $! > /tmp/langflow.pid
fi


send_to_discord "Langflow Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/langflow/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"langflow"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,langflow"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"