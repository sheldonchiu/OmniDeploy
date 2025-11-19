#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up ComfyUI ###"
log "Setting up ComfyUI"
if [[ "$REINSTALL_COMFYUI" || ! -f "$VENV_DIR/comfyui.prepared" ]]; then

    
    rm -rf $VENV_DIR/comfyui-env
    
    echo "### Installing Python ###"
    
    $UV_INSTALL_DIR/uv venv --seed --python 3.13 $VENV_DIR/comfyui-env
    
    source $VENV_DIR/comfyui-env/bin/activate
    
    python $WORKING_DIR/utils/create_symlinks.py $current_dir/folder_mapping.json $MODEL_DIR $REPO_DIR/models

    $UV_INSTALL_DIR/uv pip install comfy-cli

    $UV_INSTALL_DIR/uv pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu130

    comfy --workspace=$ROOT_REPO_DIR --skip-prompt install --nvidia
    
    touch $VENV_DIR/comfyui.prepared
else
    
    $UV_INSTALL_DIR/uv python install 3.13
    source $VENV_DIR/comfyui-env/bin/activate
    
fi
log "Finished Preparing Environment for ComfyUI"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for ComfyUI ###"
  log "Downloading Model for ComfyUI"
  bash $WORKING_DIR/utils/sd_model_download/main.sh
  log "Finished Downloading Models for ComfyUI"
else
  log "Skipping Model Download for ComfyUI"
fi




if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting ComfyUI ###"
  log "Starting ComfyUI"
  cd "$REPO_DIR"
  mkdir -p $ROOT_REPO_DIR/settings/comfyui
  PYTHONUNBUFFERED=1 service_loop "python main.py --dont-print-server --port $COMFYUI_PORT --user-directory $ROOT_REPO_DIR/settings/comfyui ${EXTRA_COMFYUI_ARGS}" > $LOG_DIR/comfyui.log 2>&1 &
  echo $! > /tmp/comfyui.pid
fi


send_to_discord "ComfyUI Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/comfyui/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"comfyui"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,comfyui"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"