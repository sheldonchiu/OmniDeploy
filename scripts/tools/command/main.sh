#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Command Server ###"
log "Setting up Command Server"
if [[ "$REINSTALL_COMMAND" || ! -f "/tmp/command.prepared" ]]; then

    
    rm -rf $VENV_DIR/command-env
    
    echo "### Installing Python ###"
    
    $UV_INSTALL_DIR/uv venv --seed --python 3.10 $VENV_DIR/command-env
    
    source $VENV_DIR/command-env/bin/activate
    
    $UV_INSTALL_DIR/uv pip install -r requirements.txt
    
    touch /tmp/command.prepared
else
    
    source $VENV_DIR/command-env/bin/activate
    
fi
log "Finished Preparing Environment for Command Server"





if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Command Server ###"
  log "Starting Command Server"
  cd $current_dir/server
  PYTHONUNBUFFERED=1 service_loop "python -m $UV_INSTALL_DIR/uvicorn main:app --host 0.0.0.0 --port 7000" > $LOG_DIR/command.log 2>&1 &
  echo $! > /tmp/command.pid

  if [[ -n "${DISCORD_BOT}" ]]; then
    PYTHONUNBUFFERED=1 service_loop "python process.py" > $LOG_DIR/command_process.log 2>&1 &
    echo $! > /tmp/command_process.pid
  fi

  cd ..
fi


send_to_discord "Command Server Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/command/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"command"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,command"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"