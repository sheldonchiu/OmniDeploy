#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Wan2GP ###"
log "Setting up Wan2GP"
if [[ "$REINSTALL_WAN2GP" || ! -f "$VENV_DIR/wan2gp.prepared" ]]; then

    
    TARGET_REPO_URL="https://github.com/deepbeepmeep/Wan2GP.git" \
    TARGET_REPO_DIR=$REPO_DIR \
    UPDATE_REPO=$WAN2GP_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$WAN2GP_UPDATE_REPO_COMMIT \
    prepare_repo 
    rm -rf $VENV_DIR/wan2gp-env
    
    echo "### Installing Python ###"
    
    $UV_INSTALL_DIR/uv venv --seed --python 3.10 $VENV_DIR/wan2gp-env
    
    source $VENV_DIR/wan2gp-env/bin/activate
    
    python $WORKING_DIR/utils/create_symlinks.py $current_dir/folder_mapping.json $MODEL_DIR $REPO_DIR/models

    cd $REPO_DIR
    $UV_INSTALL_DIR/uv pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu126
    $UV_INSTALL_DIR/uv pip install -r requirements.txt

    $UV_INSTALL_DIR/uv pip install sageattention==1.0.6 

    cd "$REPO_DIR/custom_nodes"
    if [[ ! -d "comfyui-manager" ]]; then
      git clone https://github.com/ltdrdata/ComfyUI-Manager comfyui-manager
    fi
    
    touch $VENV_DIR/wan2gp.prepared
else
    
    $UV_INSTALL_DIR/uv python install 3.10
    source $VENV_DIR/wan2gp-env/bin/activate
    
fi
log "Finished Preparing Environment for Wan2GP"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for Wan2GP ###"
  log "Downloading Model for Wan2GP"
  bash $WORKING_DIR/utils/sd_model_download/main.sh
  log "Finished Downloading Models for Wan2GP"
else
  log "Skipping Model Download for Wan2GP"
fi




if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Wan2GP ###"
  log "Starting Wan2GP"
  cd "$REPO_DIR"


  mkdir -p $ROOT_REPO_DIR/settings/wan2gp
  GRADIO_ROOT_PATH="/wan2gp" PYTHONUNBUFFERED=1 service_loop "python gradio_server.py --server-name 0.0.0.0 > $LOG_DIR/wan2gp.log 2>&1 &
   
  echo $! > /tmp/wan2gp.pid
fi


send_to_discord "Wan2GP Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/wan2gp/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"wan2gp"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,wan2gp"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"