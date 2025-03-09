#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Stable Diffusion Comfy ###"
log "Setting up Stable Diffusion Comfy"
if [[ "$REINSTALL_SD_COMFY" || ! -f "/tmp/sd_comfy.prepared" ]]; then

    
    TARGET_REPO_URL="https://github.com/comfyanonymous/ComfyUI.git" \
    TARGET_REPO_DIR=$REPO_DIR \
    UPDATE_REPO=$SD_COMFY_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$SD_COMFY_UPDATE_REPO_COMMIT \
    prepare_repo 
    rm -rf $VENV_DIR/sd_comfy-env
    
    
    echo "### Installing Python 3.12 ###"
    apt-get install -y software-properties-common > /dev/null
    add-apt-repository -y ppa:deadsnakes/ppa
    apt-get update -qq
    apt-get install -y python3.12 \
     python3.12-venv \
     python3.12-dev \
     python3.12-tk > /dev/null

    python3.12 -m venv $VENV_DIR/sd_comfy-env
    
    source $VENV_DIR/sd_comfy-env/bin/activate

    pip install pip==24.0
    pip install --upgrade wheel setuptools
    
    python $WORKING_DIR/utils/create_symlinks.py $current_dir/folder_mapping.yaml $MODEL_DIR $REPO_DIR/models

    cd $REPO_DIR
    pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu126
    pip install -r requirements.txt

    cd "$REPO_DIR/custom_nodes"
    if [[ ! -d "comfyui-manager" ]]; then
      git clone https://github.com/ltdrdata/ComfyUI-Manager comfyui-manager
    fi
    
    touch /tmp/sd_comfy.prepared
else
    
    source $VENV_DIR/sd_comfy-env/bin/activate
    
fi
log "Finished Preparing Environment for Stable Diffusion Comfy"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for Stable Diffusion Comfy ###"
  log "Downloading Model for Stable Diffusion Comfy"
  bash $WORKING_DIR/utils/sd_model_download/main.sh
  log "Finished Downloading Models for Stable Diffusion Comfy"
else
  log "Skipping Model Download for Stable Diffusion Comfy"
fi




if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Stable Diffusion Comfy ###"
  log "Starting Stable Diffusion Comfy"
  cd "$REPO_DIR"
  PYTHONUNBUFFERED=1 service_loop "python main.py --dont-print-server --highvram --port $SD_COMFY_PORT ${EXTRA_SD_COMFY_ARGS}" > $LOG_DIR/sd_comfy.log 2>&1 &
  echo $! > /tmp/sd_comfy.pid
fi


send_to_discord "Stable Diffusion Comfy Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/sd-comfy/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"sd_comfy"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,sd_comfy"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"