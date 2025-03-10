#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Stable Diffusion WebUI ###"
log "Setting up Stable Diffusion WebUI"
if [[ "$REINSTALL_SD_A111" || ! -f "/tmp/sd_a111.prepared" ]]; then

    TARGET_REPO_URL="https://github.com/AUTOMATIC1111/stable-diffusion-webui.git" \
    TARGET_REPO_DIR=$REPO_DIR \
    UPDATE_REPO=$SD_A111_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$SD_A111_UPDATE_REPO_COMMIT \
    prepare_repo 

    # git clone extensions that has their own model folder
    if [[ ! -d "${REPO_DIR}/extensions/sd-webui-controlnet" ]]; then
        git clone https://github.com/Mikubill/sd-webui-controlnet.git "${REPO_DIR}/extensions/sd-webui-controlnet"
    fi

    symlinks=(
        "$REPO_DIR/outputs:$IMAGE_OUTPUTS_DIR/stable-diffusion-webui"
        "$MODEL_DIR:$WORKING_DIR/models"
        "$MODEL_DIR/sd:$LINK_MODEL_TO"
        "$MODEL_DIR/lora:$LINK_LORA_TO"
        "$MODEL_DIR/vae:$LINK_VAE_TO"
        "$MODEL_DIR/hypernetwork:$LINK_HYPERNETWORK_TO"
        "$MODEL_DIR/controlnet:$LINK_CONTROLNET_TO"
        "$MODEL_DIR/embedding:$LINK_EMBEDDING_TO"
    )
    prepare_link  "${symlinks[@]}"

    #Prepare the controlnet model dir
    #mkdir -p $MODEL_DIR/controlnet/
    # cp $LINK_CONTROLNET_TO/*.yaml $MODEL_DIR/controlnet/
    rm -rf $VENV_DIR/sd_a111-env
    
    
    echo "### Installing Python 3.1 ###"
    apt-get install -y software-properties-common > /dev/null
    add-apt-repository -y ppa:deadsnakes/ppa
    apt-get update -qq
    apt-get install -y python3.1 \
     python3.1-venv \
     python3.1-dev \
     python3.1-tk > /dev/null

    python3.1 -m venv $VENV_DIR/sd_a111-env
    
    source $VENV_DIR/sd_a111-env/bin/activate

    pip install pip==24.0
    pip install --upgrade wheel setuptools
    
    # fix install issue with pycairo, which is needed by sd-webui-controlnet
    apt-get install -y libcairo2-dev libjpeg-dev libgif-dev
    pip uninstall -y torch torchvision torchaudio protobuf lxml

    export PYTHONPATH="$PYTHONPATH:$REPO_DIR"
    # must run inside webui dir since env['PYTHONPATH'] = os.path.abspath(".") existing in launch.py
    cd $REPO_DIR
    python $current_dir/preinstall.py
    cd $current_dir

    pip install xformers
    
    touch /tmp/sd_a111.prepared
else
    
    source $VENV_DIR/sd_a111-env/bin/activate
    
fi
log "Finished Preparing Environment for Stable Diffusion WebUI"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for Stable Diffusion WebUI ###"
  log "Downloading Model for Stable Diffusion WebUI"
  bash $current_dir/../utils/sd_model_download/main.sh
  log "Finished Downloading Models for Stable Diffusion WebUI"
else
  log "Skipping Model Download for Stable Diffusion WebUI"
fi




if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Stable Diffusion WebUI ###"
  log "Starting Stable Diffusion WebUI"
  cd $REPO_DIR
  auth=""
  if [[ -n "${SD_WEBUI_GRADIO_AUTH}" ]]; then
    auth="--gradio-auth ${SD_WEBUI_GRADIO_AUTH}"
  fi
  PYTHONUNBUFFERED=1 service_loop "python webui.py --xformers --port $SD_A111_PORT --subpath sd-webui $auth --controlnet-dir $MODEL_DIR/controlnet/ --enable-insecure-extension-access ${EXTRA_SD_A111_ARGS}" > $LOG_DIR/sd_a111.log 2>&1 &
  echo $! > /tmp/sd_a111.pid
fi


send_to_discord "Stable Diffusion WebUI Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/sd-a111/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"sd_a111"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,sd_a111"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"