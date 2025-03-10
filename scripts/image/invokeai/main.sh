#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Stable Diffusion InvokeAI ###"
log "Setting up Stable Diffusion InvokeAI"
if [[ "$REINSTALL_INVOKEAI" || ! -f "/tmp/invokeai.prepared" ]]; then

    mkdir -p $DATA_DIR/invokeai_models
    mkdir -p $INVOKEAI_ROOT/models

    symlinks=(
      "$INVOKEAI_ROOT/outputs:$IMAGE_OUTPUTS_DIR/invokeai"
      "$DATA_DIR/invokeai_models:$INVOKEAI_ROOT/models"
    )
    prepare_link "${symlinks[@]}"
    rm -rf $VENV_DIR/invokeai-env
    
    echo "### Installing Python ###"
    
    $UV_INSTALL_DIR/uv venv --seed --python 3.11 $VENV_DIR/invokeai-env
    
    source $VENV_DIR/invokeai-env/bin/activate
    
    if [[ "$INVOKEAI_INSTALL_PYPATCHMATCH" ]]; then
      echo "Installing pypatchmatch"
      apt-get install build-essential -y > /dev/null
      apt-get install python3-opencv libopencv-dev -y > /dev/null
      $UV_INSTALL_DIR/uv pip install pypatchmatch
    fi

    $UV_INSTALL_DIR/uv pip install invokeai --index https://download.pytorch.org/whl/cu124
    
    touch /tmp/invokeai.prepared
else
    
    source $VENV_DIR/invokeai-env/bin/activate
    
fi
log "Finished Preparing Environment for Stable Diffusion InvokeAI"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for Stable Diffusion InvokeAI ###"
  log "Downloading Model for Stable Diffusion InvokeAI"
  bash $current_dir/../utils/sd_model_download/main.sh
  log "Finished Downloading Models for Stable Diffusion InvokeAI"
else
  log "Skipping Model Download for Stable Diffusion InvokeAI"
fi




if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Stable Diffusion InvokeAI ###"
  log "Starting Stable Diffusion InvokeAI"
  cd "$REPO_DIR"
  mkdir -p $ROOT_REPO_DIR/settings/invokeai
  PYTHONUNBUFFERED=1 service_loop "invokeai-web --config $current_dir/config.yaml \
  ${EXTRA_INVOKEAI_ARGS}" > $LOG_DIR/invokeai.log 2>&1 &
  echo $! > /tmp/invokeai.pid
fi


send_to_discord "Stable Diffusion InvokeAI Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/invokeai/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"invokeai"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,invokeai"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"