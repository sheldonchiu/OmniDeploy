#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up GPT-SoVITS ###"
log "Setting up GPT-SoVITS"
if [[ "$REINSTALL_GPT_SOVITS" || ! -f "$VENV_DIR/gpt_sovits.prepared" ]]; then

    
    TARGET_REPO_URL="https://github.com/RVC-Boss/GPT-SoVITS.git" \
    TARGET_REPO_DIR=$REPO_DIR \
    UPDATE_REPO=$GPT_SOVITS_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$GPT_SOVITS_UPDATE_REPO_COMMIT \
    prepare_repo 
    rm -rf $VENV_DIR/gpt_sovits-env
    
    echo "### Installing Python ###"
    
    $UV_INSTALL_DIR/uv venv --seed --python 3.10 $VENV_DIR/gpt_sovits-env
    
    source $VENV_DIR/gpt_sovits-env/bin/activate
    
    $UV_INSTALL_DIR/uv pip install torch==2.1.2 torchvision==0.16.2 torchaudio==2.1.2 --index https://download.pytorch.org/whl/cu121

    apt-get install -y --no-install-recommends tzdata ffmpeg libsox-dev parallel > /dev/null

    $UV_INSTALL_DIR/uv pip install -r requirements.txt

    cd "$REPO_DIR"
    ln -s $MODEL_DIR GPT_SoVITS/pretrained_models
    chmod +x Docker/download.sh
    bash Docker/download.sh
    $UV_INSTALL_DIR/uv run Docker/download.py
    $UV_INSTALL_DIR/uv run nltk.downloader averaged_perceptron_tagger cmudict
    
    touch $VENV_DIR/gpt_sovits.prepared
else
    
    $UV_INSTALL_DIR/uv python install 3.10
    source $VENV_DIR/gpt_sovits-env/bin/activate
    
fi
log "Finished Preparing Environment for GPT-SoVITS"





if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting GPT-SoVITS ###"
  log "Starting GPT-SoVITS"
  cd "$REPO_DIR"

  PYTHONUNBUFFERED=1 service_loop "$UV_INSTALL_DIR/uv run webui.py > $LOG_DIR/gpt_sovits.log 2>&1 &
   
  echo $! > /tmp/gpt_sovits.pid
fi


send_to_discord "GPT-SoVITS Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/gpt-sovits/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"gpt_sovits"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,gpt_sovits"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"