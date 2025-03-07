#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Stable Diffusion Swarm ###"
log "Setting up Stable Diffusion Swarm"
if [[ "$REINSTALL_SD_SWARM" || ! -f "/tmp/sd_swarm.prepared" ]]; then

    
    TARGET_REPO_URL="https://github.com/Stability-AI/StableSwarmUI.git" \
    TARGET_REPO_DIR=$REPO_DIR \
    TARGET_REPO_BRANCH="master" \
    UPDATE_REPO=$SD_SWARM_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$SD_SWARM_UPDATE_REPO_COMMIT \
    prepare_repo 

    symlinks=(
        "$REPO_DIR/outputs:$IMAGE_OUTPUTS_DIR/stable-diffusion-swarm"
        "$MODEL_DIR:$WORKING_DIR/models"
        "$MODEL_DIR/sd:$LINK_MODEL_TO"
        "$MODEL_DIR/lora:$LINK_LORA_TO"
        "$MODEL_DIR/vae:$LINK_VAE_TO"
        "$MODEL_DIR/hypernetwork:$LINK_HYPERNETWORK_TO"
        "$MODEL_DIR/controlnet:$LINK_CONTROLNET_TO"
        "$MODEL_DIR/embedding:$LINK_EMBEDDING_TO"
        "$MODEL_DIR/clip_vision:$LINK_CLIP_TO"
    )
    prepare_link  "${symlinks[@]}"
    rm -rf $VENV_DIR/sd_swarm-env
    
    
    python3.10 -m venv $VENV_DIR/sd_swarm-env
    
    source $VENV_DIR/sd_swarm-env/bin/activate

    pip install pip==24.0
    pip install --upgrade wheel setuptools
    
    wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb

    apt-get update -qq
    apt-get install -qq -y dotnet-sdk-7.0
    
    touch /tmp/sd_swarm.prepared
else
    
    source $VENV_DIR/sd_swarm-env/bin/activate
    
fi
log "Finished Preparing Environment for Stable Diffusion Swarm"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for Stable Diffusion Swarm ###"
  log "Downloading Model for Stable Diffusion Swarm"
  bash $current_dir/../utils/sd_model_download/main.sh
  log "Finished Downloading Models for Stable Diffusion Swarm"
else
  log "Skipping Model Download for Stable Diffusion Swarm"
fi




if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Stable Diffusion Swarm ###"
  log "Starting Stable Diffusion Swarm"
  cd $REPO_DIR
  service_loop "bash launch-linux.sh --port 7016 --launch_mode none ${EXTRA_SD_SWARM_ARGS}" > $LOG_DIR/sd_swarm.log 2>&1 &
  echo $! > /tmp/sd_swarm.pid
fi


send_to_discord "Stable Diffusion Swarm Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/sd-swarm/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"sd_swarm"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,sd_swarm"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"