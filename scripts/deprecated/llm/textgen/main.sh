#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Text generation Webui ###"
log "Setting up Text generation Webui"
if [[ "$REINSTALL_TEXTGEN" || ! -f "/tmp/textgen.prepared" ]]; then

    # Remove stale symlink to avoid pull conflicts
    rm -rf $LINK_MODEL_TO

    TARGET_REPO_DIR=$REPO_DIR \
    TARGET_REPO_BRANCH="main" \
    TARGET_REPO_URL="https://github.com/oobabooga/text-generation-webui" \
    UPDATE_REPO=$TEXTGEN_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$TEXTGEN_UPDATE_REPO_COMMIT \
    prepare_repo
    rm -rf $VENV_DIR/textgen-env
    
    
    python3.10 -m venv $VENV_DIR/textgen-env
    
    source $VENV_DIR/textgen-env/bin/activate

    pip install pip==24.0
    pip install --upgrade wheel setuptools
    
    cd $REPO_DIR
    pip install torch torchvision torchaudio
    pip install -r requirements.txt

    mkdir -p repositories
    cd repositories
    TARGET_REPO_DIR=$REPO_DIR/repositories/GPTQ-for-LLaMa \
    TARGET_REPO_BRANCH="cuda" \
    TARGET_REPO_URL="https://github.com/qwopqwop200/GPTQ-for-LLaMa.git" \
    prepare_repo

    cd GPTQ-for-LLaMa
    python setup_cuda.py install

    pip uninstall -y llama-cpp-python
    CMAKE_ARGS="-DLLAMA_CUBLAS=on" FORCE_CMAKE=1 pip install llama-cpp-python --no-cache-dir

    pip install deepspeed

    pip install xformers
    
    touch /tmp/textgen.prepared
else
    
    source $VENV_DIR/textgen-env/bin/activate
    
fi
log "Finished Preparing Environment for Text generation Webui"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for Text generation Webui ###"
  log "Downloading Model for Text generation Webui"
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
  log "Finished Downloading Models for Text generation Webui"
else
  log "Skipping Model Download for Text generation Webui"
fi

if env | grep -q "PAPERSPACE"; then
  sed -i "s/server_port=shared.args.listen_port, inbrowser=shared.args.auto_launch, auth=auth)/server_port=shared.args.listen_port, inbrowser=shared.args.auto_launch, auth=auth, root_path='\\/textgen')/g" $REPO_DIR/server.py
fi


if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Text generation Webui ###"
  log "Starting Text generation Webui"
  cd $REPO_DIR
  share_args="--chat --listen-port $TEXTGEN_PORT --xformers ${EXTRA_TEXTGEN_ARGS}"
  if [ -v TEXTGEN_ENABLE_OPENAI_API ] && [ ! -z "$TEXTGEN_ENABLE_OPENAI_API" ];then
    loader_arg=""
    if echo "$TEXTGEN_OPENAI_MODEL" | grep -q "GPTQ"; then
      loader_arg="--loader exllama"
    fi
    if echo "$TEXTGEN_OPENAI_MODEL" | grep -q "LongChat"; then
      loader_arg+=" --max_seq_len 8192 --compress_pos_emb 4"
    fi
    PYTHONUNBUFFERED=1 OPENEDAI_PORT=7013 service_loop "python server.py --model $TEXTGEN_OPENAI_MODEL $loader_arg --extensions openai $share_args" > $LOG_DIR/textgen.log 2>&1 &
  else
    PYTHONUNBUFFERED=1 service_loop "python server.py  $share_args" > $LOG_DIR/textgen.log 2>&1 &
  fi
  echo $! > /tmp/textgen.pid

  # undo the change for git pull to work
  if env | grep -q "PAPERSPACE"; then
    sed -i "s/server_port=shared.args.listen_port, inbrowser=shared.args.auto_launch, auth=auth, root_path='\\/textgen')/server_port=shared.args.listen_port, inbrowser=shared.args.auto_launch, auth=auth)/g" $REPO_DIR/server.py
  fi
fi


send_to_discord "Text generation Webui Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/textgen/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"textgen"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,textgen"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"