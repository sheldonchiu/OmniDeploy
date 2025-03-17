#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up SwarmUI ###"
log "Setting up SwarmUI"
if [[ "$REINSTALL_SWARMUI" || ! -f "$VENV_DIR/swarmui.prepared" ]]; then

    
    TARGET_REPO_URL="https://github.com/mcmonkeyprojects/SwarmUI.git" \
    TARGET_REPO_DIR=$REPO_DIR \
    TARGET_REPO_BRANCH="master" \
    UPDATE_REPO=$SWARMUI_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$SWARMUI_UPDATE_REPO_COMMIT \
    prepare_repo 
    rm -rf $VENV_DIR/swarmui-env
    
    echo "### Installing Python ###"
    
    $UV_INSTALL_DIR/uv venv --seed --python 3.11 $VENV_DIR/swarmui-env
    
    source $VENV_DIR/swarmui-env/bin/activate
    
    python $WORKING_DIR/utils/create_symlinks.py $current_dir/folder_mapping.json $MODEL_DIR $REPO_DIR/models

    apt-get update -qq
    apt-get install -qq -y dotnet-sdk-8.0

    $UV_INSTALL_DIR/uv pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu126
    
    touch $VENV_DIR/swarmui.prepared
else
    
    $UV_INSTALL_DIR/uv python install 3.11
    source $VENV_DIR/swarmui-env/bin/activate
    
fi
log "Finished Preparing Environment for SwarmUI"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for SwarmUI ###"
  log "Downloading Model for SwarmUI"
  bash $WORKING_DIR/utils/sd_model_download/main.sh
  log "Finished Downloading Models for SwarmUI"
else
  log "Skipping Model Download for SwarmUI"
fi




if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting SwarmUI ###"
  log "Starting SwarmUI"
  cd $REPO_DIR
  mkdir $ROOT_REPO_DIR/settings/swarmui
  service_loop "bash launch-linux.sh --data_dir $ROOT_REPO_DIR/settings/swarmui --port 7016 --launch_mode none ${EXTRA_SWARMUI_ARGS}" > $LOG_DIR/swarmui.log 2>&1 &
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