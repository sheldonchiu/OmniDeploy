#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Stable Diffusion Volta ###"
log "Setting up Stable Diffusion Volta"
if [[ "$REINSTALL_SD_VOLTA" || ! -f "/tmp/sd_volta.prepared" ]]; then

    TARGET_REPO_URL="https://github.com/VoltaML/voltaML-fast-stable-diffusion.git" \
    TARGET_REPO_DIR=$REPO_DIR \
    TARGET_REPO_BRANCH=main \
    UPDATE_REPO=$SD_VOLTA_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$SD_VOLTA_UPDATE_REPO_COMMIT \
    prepare_repo

    symlinks=(
      "$REPO_DIR/outputs:$IMAGE_OUTPUTS_DIR/stable-diffusion-volta"
      "$MODEL_DIR:$WORKING_DIR/models"
      "$MODEL_DIR/sd:$LINK_MODEL_TO"
      "$MODEL_DIR/lora:$LINK_LORA_TO"
    )
    prepare_link "${symlinks[@]}"
    rm -rf $VENV_DIR/sd_volta-env
    
    
    python3.10 -m venv $VENV_DIR/sd_volta-env
    
    source $VENV_DIR/sd_volta-env/bin/activate

    pip install pip==24.0
    pip install --upgrade wheel setuptools
    
    cd $REPO_DIR
    python main.py --install-only

    pip install xformers
    
    touch /tmp/sd_volta.prepared
else
    
    source $VENV_DIR/sd_volta-env/bin/activate
    
fi
log "Finished Preparing Environment for Stable Diffusion Volta"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for Stable Diffusion Volta ###"
  log "Downloading Model for Stable Diffusion Volta"
  bash $current_dir/../utils/sd_model_download/main.sh
  log "Finished Downloading Models for Stable Diffusion Volta"
else
  log "Skipping Model Download for Stable Diffusion Volta"
fi




if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Stable Diffusion Volta ###"
  log "Starting Stable Diffusion Volta"
  cd "$REPO_DIR"
  PYTHONUNBUFFERED=1 service_loop "python main.py --port SD_VOLTA_PORT ${EXTRA_SD_VOLTA_ARGS}" > $LOG_DIR/sd_volta.log 2>&1 &
  echo $! > /tmp/sd_volta.pid
fi


send_to_discord "Stable Diffusion Volta Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/sd-volta/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"sd_volta"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,sd_volta"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"