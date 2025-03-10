#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up SwarmUI ###"
log "Setting up SwarmUI"
if [[ "$REINSTALL_SWARMUI" || ! -f "/tmp/swarmui.prepared" ]]; then

    
    TARGET_REPO_URL="https://github.com/mcmonkeyprojects/SwarmUI.git" \
    TARGET_REPO_DIR=$REPO_DIR \
    TARGET_REPO_BRANCH="master" \
    UPDATE_REPO=$SWARMUI_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$SWARMUI_UPDATE_REPO_COMMIT \
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
    rm -rf $VENV_DIR/swarmui-env
    
    echo "### Installing Python ###"
    
    $UV_INSTALL_DIR/uv venv --seed --python 3.1 $VENV_DIR/swarmui-env
    
    source $VENV_DIR/swarmui-env/bin/activate
    
    apt-get update -qq
    apt-get install -qq -y dotnet-sdk-8.0
    
    touch /tmp/swarmui.prepared
else
    
    source $VENV_DIR/swarmui-env/bin/activate
    
fi
log "Finished Preparing Environment for SwarmUI"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for SwarmUI ###"
  log "Downloading Model for SwarmUI"
  bash $current_dir/../utils/sd_model_download/main.sh
  log "Finished Downloading Models for SwarmUI"
else
  log "Skipping Model Download for SwarmUI"
fi




if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting SwarmUI ###"
  log "Starting SwarmUI"
  cd $REPO_DIR
  service_loop "bash launch-linux.sh --port 7016 --launch_mode none ${EXTRA_SWARMUI_ARGS}" > $LOG_DIR/swarmui.log 2>&1 &
  echo $! > /tmp/swarmui.pid
fi


send_to_discord "SwarmUI Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/swarmui/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"swarmui"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,swarmui"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"