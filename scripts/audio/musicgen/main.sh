#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Musicgen ###"
log "Setting up Musicgen"
if [[ "$REINSTALL_MUSICGEN" || ! -f "/tmp/musicgen.prepared" ]]; then

    TARGET_REPO_DIR=$REPO_DIR \
    TARGET_REPO_BRANCH="main" \
    TARGET_REPO_URL="https://github.com/facebookresearch/audiocraft.git" \
    UPDATE_REPO=$MUSICGEN_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$MUSICGEN_UPDATE_REPO_COMMIT \
    prepare_repo
    rm -rf $VENV_DIR/musicgen-env
    
    
    python3.10 -m venv $VENV_DIR/musicgen-env
    
    source $VENV_DIR/musicgen-env/bin/activate

    pip install pip==24.0
    pip install --upgrade wheel setuptools
    
    cd $REPO_DIR
    pip install 'torch>=2.0'
    pip install -e .
    
    touch /tmp/musicgen.prepared
else
    
    source $VENV_DIR/musicgen-env/bin/activate
    
fi
log "Finished Preparing Environment for Musicgen"


if env | grep -q "PAPERSPACE"; then
  sed -i "s|launch_kwargs = {}|launch_kwargs = {'root_path': '/musicgen'}|g" $REPO_DIR/demos/musicgen_app.py
fi


if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Musicgen ###"
  log "Starting Musicgen"
  cd $REPO_DIR
  PYTHONUNBUFFERED=1 service_loop "python demos/musicgen_app.py --server_port $MUSICGEN_PORT  ${EXTRA_MUSICGEN_ARGS}" > $LOG_DIR/musicgen.log 2>&1 &
  echo $! > /tmp/musicgen.pid

  if env | grep -q "PAPERSPACE"; then
    sed -i "s|launch_kwargs = {'root_path': '/musicgen'}|launch_kwargs = {}|g" $REPO_DIR/demos/musicgen_app.py
  fi
fi


send_to_discord "Musicgen Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/musicgen/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"musicgen"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,musicgen"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"