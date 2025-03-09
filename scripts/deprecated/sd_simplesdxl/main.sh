#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Stable Diffusion SimpleSDXL ###"
log "Setting up Stable Diffusion SimpleSDXL"
if [[ "$REINSTALL_SD_SIMPLESDXL" || ! -f "/tmp/sd_simplesdxl.prepared" ]]; then

    
    TARGET_REPO_URL="https://github.com/metercai/SimpleSDXL.git" \
    TARGET_REPO_DIR=$REPO_DIR \
    TARGET_REPO_BRANCH="SimpleSDXL" \
    UPDATE_REPO=$SD_SIMPLESDXL_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$SD_SIMPLESDXL_UPDATE_REPO_COMMIT \
    prepare_repo 

    symlinks=(
        # "$REPO_DIR/outputs:$IMAGE_OUTPUTS_DIR/stable-diffusion-fooocus"
        "$MODEL_DIR:$WORKING_DIR/models"
        "$MODEL_DIR/sd:$LINK_MODEL_TO"
        "$MODEL_DIR/lora:$LINK_LORA_TO"
        "$MODEL_DIR/vae:$LINK_VAE_TO"
        "$MODEL_DIR/hypernetwork:$LINK_HYPERNETWORK_TO"
        "$MODEL_DIR/controlnet:$LINK_CONTROLNET_TO"
        "$MODEL_DIR/embedding:$LINK_EMBEDDING_TO"
    )
    prepare_link  "${symlinks[@]}"
    rm -rf $VENV_DIR/sd_simplesdxl-env
    
    
    python3.10 -m venv $VENV_DIR/sd_simplesdxl-env
    
    source $VENV_DIR/sd_simplesdxl-env/bin/activate

    pip install pip==24.0
    pip install --upgrade wheel setuptools
    
    pip install pygit2 packaging

    cd $REPO_DIR
    pip install torch==2.1.0 torchvision==0.16.0 --extra-index-url https://download.pytorch.org/whl/cu121
    pip install -r requirements_versions.txt
    
    touch /tmp/sd_simplesdxl.prepared
else
    
    source $VENV_DIR/sd_simplesdxl-env/bin/activate
    
fi
log "Finished Preparing Environment for Stable Diffusion SimpleSDXL"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for Stable Diffusion SimpleSDXL ###"
  log "Downloading Model for Stable Diffusion SimpleSDXL"
  bash $current_dir/../utils/sd_model_download/main.sh
  log "Finished Downloading Models for Stable Diffusion SimpleSDXL"
else
  log "Skipping Model Download for Stable Diffusion SimpleSDXL"
fi




if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Stable Diffusion SimpleSDXL ###"
  log "Starting Stable Diffusion SimpleSDXL"
  cd $REPO_DIR
  # tmp fix
  if [ -f .token_user.pem ]; then
    rm .token_user.pem
  fi
  PYTHONUNBUFFERED=1 service_loop "python entry_with_update.py --listen 127.0.0.1 --port 7017 --webroot /sd-simplesdxl" > $LOG_DIR/sd_simplesdxl.log 2>&1 &
  echo $! > /tmp/sd_simplesdxl.pid
fi


send_to_discord "Stable Diffusion SimpleSDXL Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/sd-simplesdxl/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"sd_simplesdxl"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,sd_simplesdxl"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"