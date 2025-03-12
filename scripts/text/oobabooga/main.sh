#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Oobabooga Text generation Webui ###"
log "Setting up Oobabooga Text generation Webui"
if [[ "$REINSTALL_OOBABOOGA" || ! -f "$VENV_DIR/oobabooga.prepared" ]]; then

    # Remove stale symlink to avoid pull conflicts
    rm -rf $LINK_MODEL_TO

    TARGET_REPO_DIR=$REPO_DIR \
    TARGET_REPO_BRANCH="main" \
    TARGET_REPO_URL="https://github.com/oobabooga/text-generation-webui" \
    UPDATE_REPO=$OOBABOOGA_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$OOBABOOGA_UPDATE_REPO_COMMIT \
    prepare_repo
    rm -rf $VENV_DIR/oobabooga-env
    
    echo "### Installing Python ###"
    
    $UV_INSTALL_DIR/uv venv --seed --python 3.11 $VENV_DIR/oobabooga-env
    
    source $VENV_DIR/oobabooga-env/bin/activate
    
    cd $REPO_DIR
    uv pip install torch==2.4.1 torchvision==0.19.1 torchaudio==2.4.1 --index-url https://download.pytorch.org/whl/cu121
    uv pip install -r requirements.txt
    
    touch $VENV_DIR/oobabooga.prepared
else
    
    source $VENV_DIR/oobabooga-env/bin/activate
    
fi
log "Finished Preparing Environment for Oobabooga Text generation Webui"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for Oobabooga Text generation Webui ###"
  log "Downloading Model for Oobabooga Text generation Webui"
  # Prepare model dir and link it under the models folder inside the repo
  mkdir -p $MODEL_DIR
  rm -rf $LINK_MODEL_TO
  ln -s $MODEL_DIR $LINK_MODEL_TO
  if [[ ! -f $MODEL_DIR/config.yaml ]]; then 
      current_dir_save=$(pwd) 
      cd $REPO_DIR
      commit=$(git rev-parse HEAD)
      wget -q https://raw.githubusercontent.com/oobabooga/text-generation-webui/$commit/models/config.yaml -P $MODEL_DIR
      cd $current_dir_save
  fi

  llm_model_download
  log "Finished Downloading Models for Oobabooga Text generation Webui"
else
  log "Skipping Model Download for Oobabooga Text generation Webui"
fi




if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Oobabooga Text generation Webui ###"
  log "Starting Oobabooga Text generation Webui"
  cd $REPO_DIR
  share_args="--subpath /oobabooga --listen-port $OOBABOOGA_PORT ${EXTRA_OOBABOOGA_ARGS}"
  if [ -v OOBABOOGA_ENABLE_OPENAI_API ] && [ ! -z "$OOBABOOGA_ENABLE_OPENAI_API" ];then
    loader_arg=""
    if echo "$OOBABOOGA_OPENAI_MODEL" | grep -q "GPTQ"; then
      loader_arg="--loader exllama"
    fi
    if echo "$OOBABOOGA_OPENAI_MODEL" | grep -q "LongChat"; then
      loader_arg+=" --max_seq_len 8192 --compress_pos_emb 4"
    fi
    PYTHONUNBUFFERED=1 service_loop "python server.py --model $OOBABOOGA_OPENAI_MODEL $loader_arg --api --api-port $OOBABOOGA_OPENAI_API_PORT $share_args" > $LOG_DIR/oobabooga.log 2>&1 &
  else
    PYTHONUNBUFFERED=1 service_loop "python server.py  $share_args" > $LOG_DIR/oobabooga.log 2>&1 &
  fi
  echo $! > /tmp/oobabooga.pid
fi


send_to_discord "Oobabooga Text generation Webui Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/oobabooga/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"oobabooga"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,oobabooga"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"