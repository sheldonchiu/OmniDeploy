#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Kohya SD Trainer ###"
log "Setting up Kohya SD Trainer"
if [[ "$REINSTALL_KOHYA_SS" || ! -f "/tmp/kohya_ss.prepared" ]]; then

    TARGET_REPO_DIR=$REPO_DIR \
    TARGET_REPO_BRANCH="master" \
    TARGET_REPO_URL="https://github.com/bmaltais/kohya_ss.git" \
    UPDATE_REPO=$KOHYA_SS_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$KOHYA_SS_UPDATE_REPO_COMMIT \
    prepare_repo
    rm -rf $VENV_DIR/kohya_ss-env
    
    
    python3 -m venv /tmp/kohya_ss-env
    
    source $VENV_DIR/kohya_ss-env/bin/activate

    pip install pip==24.0
    pip install --upgrade wheel setuptools
    
    cd $REPO_DIR
    pip install torch==2.0.1 torchvision==0.15.2
    pip install xformers==0.0.20 bitsandbytes==0.35.0
    pip install accelerate==0.15.0 tensorboard==2.12.1 tensorflow==2.12.0
    pip install -r requirements.txt

    mkdir -p /root/.cache/huggingface/accelerate/
    cp config_files/accelerate/default_config.yaml /root/.cache/huggingface/accelerate/default_config.yaml
    
    touch /tmp/kohya_ss.prepared
else
    
    source $VENV_DIR/kohya_ss-env/bin/activate
    
fi
log "Finished Preparing Environment for Kohya SD Trainer"





if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Kohya SD Trainer ###"
  log "Starting Kohya SD Trainer"
  cd $REPO_DIR
  auth=""
  if [[ -n "${KOHYA_USERNAME}" ]] && [[ -n "${KOHYA_PASSWORD}" ]]; then
    auth="--username=$KOHYA_USERNAME --password=$KOHYA_PASSWORD"
  fi
  PYTHONUNBUFFERED=1 service_loop "python kohya_gui.py --headless --server_port=$KOHYA_SS_PORT $auth ${EXTRA_KOHYA_SS_ARGS}" > $LOG_DIR/kohya_ss.log 2>&1 &
  echo $! > /tmp/kohya_ss.pid
fi


send_to_discord "Kohya SD Trainer Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/kohya-ss/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"kohya_ss"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,kohya_ss"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"