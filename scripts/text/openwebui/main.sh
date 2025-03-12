#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Open WebUI ###"
log "Setting up Open WebUI"
if [[ "$REINSTALL_OPENWEBUI" || ! -f "$VENV_DIR/openwebui.prepared" ]]; then

    
    rm -rf $VENV_DIR/openwebui-env
    
    echo "### Installing Python ###"
    
    $UV_INSTALL_DIR/uv venv --seed --python 3.11 $VENV_DIR/openwebui-env
    
    source $VENV_DIR/openwebui-env/bin/activate
    
    $UV_INSTALL_DIR/uv pip install -U open-webui
    
    touch $VENV_DIR/openwebui.prepared
else
    
    source $VENV_DIR/openwebui-env/bin/activate
    
fi
log "Finished Preparing Environment for Open WebUI"





if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Open WebUI ###"
  log "Starting Open WebUI"
  PYTHONUNBUFFERED=1 service_loop "uvx --python $VENV_DIR/openwebui-env/bin/python open-webui serve --port 7021" > $LOG_DIR/openwebui.log 2>&1 &
  echo $! > /tmp/openwebui.pid
fi


send_to_discord "Open WebUI Started"


echo "### Done ###"