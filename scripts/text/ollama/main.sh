#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Ollama ###"
log "Setting up Ollama"
if [[ "$REINSTALL_OLLAMA" || ! -f "$VENV_DIR/ollama.prepared" ]]; then

    
    rm -rf $VENV_DIR/ollama-env
    
    if [[ -d /usr/lib/ollama ]]; then
      rm -rf /usr/lib/ollama
    fi

    curl -L https://ollama.com/download/ollama-linux-amd64.tgz | tar -C /usr -xzf -
    
    touch $VENV_DIR/ollama.prepared
else
    
    log "Environment already prepared"
    
fi
log "Finished Preparing Environment for Ollama"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for Ollama ###"
  log "Downloading Model for Ollama"
  IFS=',' read -ra ollama_model_list <<< "$OLLAMA_MODEL_LIST"
  ollama_args=""
  if [[ -n "$OLLAMA_USE_INSECURE" ]]; then
    ollama_args="--insecure"
  fi
  for model in "${ollama_model_list[@]}"
  do
    ollama pull "$model" $ollama_args
  done
  log "Finished Downloading Models for Ollama"
else
  log "Skipping Model Download for Ollama"
fi




if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Ollama ###"
  log "Starting Ollama"
  PYTHONUNBUFFERED=1 service_loop "/usr/bin/ollama serve" > $LOG_DIR/ollama.log 2>&1 &
  echo $! > /tmp/ollama.pid
fi


send_to_discord "Ollama Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/ollama/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"ollama"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,ollama"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"