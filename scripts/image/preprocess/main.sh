#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up preprocess ###"
log "Setting up preprocess"
if [[ "$REINSTALL_PREPROCESS" || ! -f "/tmp/preprocess.prepared" ]]; then

    TARGET_REPO_DIR=$PREPROCESS_REPO_DIR \
    TARGET_REPO_BRANCH="main" \
    TARGET_REPO_URL="https://github.com/sheldonchiu/paperspace-sd-auto-preprocess.git" \
    prepare_repo

    TARGET_REPO_DIR=$TRAINER_REPO_DIR \
    TARGET_REPO_BRANCH="sdxl" \
    TARGET_REPO_URL="https://github.com/sheldonchiu/kohya-trainer-paperspace.git" \
    UPDATE_REPO="auto" \
    prepare_repo  
    rm -rf $VENV_DIR/preprocess-env
    
    
    python3 -m venv /tmp/preprocess-env
    
    source $VENV_DIR/preprocess-env/bin/activate

    pip install pip==24.0
    pip install --upgrade wheel setuptools
    
    cd $PREPROCESS_REPO_DIR/preprocess
    bash prepare_env.sh

    if env | grep -q "PAPERSPACE"; then
      ln -s /storage /notebooks/storage
      ln -s /tmp /notebooks/tmp
    fi
    
    touch /tmp/preprocess.prepared
else
    
    source $VENV_DIR/preprocess-env/bin/activate
    
fi
log "Finished Preparing Environment for preprocess"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for preprocess ###"
  log "Downloading Model for preprocess"
  bash $current_dir/../utils/sd_model_download/main.sh
  log "Finished Downloading Models for preprocess"
else
  log "Skipping Model Download for preprocess"
fi

cd $current_dir/../kosmos2
bash control.sh stop


if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting preprocess ###"
  log "Starting preprocess"
  cd $PREPROCESS_REPO_DIR/preprocess

  python main.py > $LOG_DIR/preprocess.log 2>&1 &
  echo $! > /tmp/preprocess.pid
fi


send_to_discord "preprocess Started"


echo "### Done ###"