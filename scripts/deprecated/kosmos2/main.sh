#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Kosmos2 ###"
log "Setting up Kosmos2"
if [[ "$REINSTALL_KOSMOS2" || ! -f "/tmp/kosmos2.prepared" ]]; then

    TARGET_REPO_DIR=$REPO_DIR \
    TARGET_REPO_BRANCH="master" \
    TARGET_REPO_URL="https://github.com/sheldonchiu/unilm.git" \
    UPDATE_REPO="auto" \
    prepare_repo

    TARGET_REPO_DIR=/tmp/apex \
    TARGET_REPO_BRANCH="master" \
    TARGET_REPO_URL="https://github.com/NVIDIA/apex.git" \
    UPDATE_REPO="commit" \
    UPDATE_REPO_COMMIT="7b2e71b0d4013f8e2f9f1c8dd21980ff1d76f1b6" \
    prepare_repo  
    rm -rf $VENV_DIR/kosmos2-env
    
    echo "### Installing Python ###"
    
    uv venv --seed --python 3.10 $VENV_DIR/kosmos2-env
    
    source $VENV_DIR/kosmos2-env/bin/activate
    
    cd $REPO_DIR/kosmos-2

    pip install torch==1.13.1+cu116 torchvision==0.14.1+cu116 torchaudio==0.13.1 --extra-index-url https://download.pytorch.org/whl/cu116
    pip install xformers==0.0.16
    pip install protobuf==3.20.3 pytorch-extension

    pip install fairseq/
    pip install infinibatch/
    pip install torchscale/
    pip install open_clip/
    pip install  git+https://github.com/microsoft/DeepSpeed.git@jeffra/engine-xthru-v2
    pip install numpy==1.23.0 scipy==1.8.0 tiktoken \
     ftfy sentencepiece==0.1.99 httpcore==0.17.3 \
     gradio==3.37.0 spacy==3.6.0 thinc==8.1.10 \
     pydantic==1.10.11 opencv-python-headless==4.8.0.74 \
     tensorboardX==1.8



    cd /tmp/apex
    gpu_name=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader,nounits)
    gpu_name=$(echo $gpu_name | sed 's/ //g')
    case $gpu_name in
      *A4000*)
        pip install -v --disable-pip-version-check --no-cache-dir --no-build-isolation  .
        wget -q https://huggingface.co/sheldonxxxx/apex-paperspace-binary/resolve/main/apex_a4000.tar.gz
        tar -xzf apex_a4000.tar.gz -C $VENV_DIR/kosmos2-env/lib/python3.9/site-packages/
        ;;
      *P5000*)
        pip install -v --disable-pip-version-check --no-cache-dir --no-build-isolation  .
        wget -q https://huggingface.co/sheldonxxxx/apex-paperspace-binary/resolve/main/apex_p5000.tar.gz
        tar -xzf apex_p5000.tar.gz -C $VENV_DIR/kosmos2-env/lib/python3.9/site-packages/
        ;;
      *RTX5000*)
        pip install -v --disable-pip-version-check --no-cache-dir --no-build-isolation  .
        wget -q https://huggingface.co/sheldonxxxx/apex-paperspace-binary/resolve/main/apex_rtx5000.tar.gz
        tar -xzf apex_rtx5000.tar.gz -C $VENV_DIR/kosmos2-env/lib/python3.9/site-packages/
        ;;
      *)
        echo "No apex binary for $gpu_name, building from source"
        pip install -v --disable-pip-version-check --no-cache-dir --no-build-isolation --config-settings "--build-option=--cpp_ext" --config-settings "--build-option=--cuda_ext" ./
        ;;
    esac
    cd $REPO_DIR
    
    touch /tmp/kosmos2.prepared
else
    
    source $VENV_DIR/kosmos2-env/bin/activate
    
fi
log "Finished Preparing Environment for Kosmos2"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for Kosmos2 ###"
  log "Downloading Model for Kosmos2"
  
  # Prepare model dir and link it under the models folder inside the repo
  mkdir -p $MODEL_DIR
  cd $MODEL_DIR
  aria2c --file-allocation=none -c -x 16 -s 16 --summary-interval=0 --console-log-level=warn --continue  --out=kosmos-2.pt "https://huggingface.co/sheldonxxxx/kosmos-2/resolve/main/kosmos-2-min.pt"
  log "Finished Downloading Models for Kosmos2"
else
  log "Skipping Model Download for Kosmos2"
fi

if env | grep -q "PAPERSPACE"; then
  sed -i "s/demo.launch()/demo.launch(root_path='\\/kosmos2')/g" $REPO_DIR/kosmos-2/demo/gradio_app.py
fi


if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Kosmos2 ###"
  log "Starting Kosmos2"
  cd $REPO_DIR/kosmos-2
  model_path=$MODEL_DIR/kosmos-2.pt

  master_port=$((RANDOM%1000+20000))

  CUDA_LAUNCH_BLOCKING=1 CUDA_VISIBLE_DEVICES=0 service_loop "python -m torch.distributed.launch --master_port=$master_port --nproc_per_node=1 demo/gradio_app.py None \
      --task generation_obj \
      --path $model_path \
      --model-overrides "{'visual_pretrained': '',
              'dict_path':'data/dict.txt'}" \
      --dict-path 'data/dict.txt' \
      --required-batch-size-multiple 1 \
      --remove-bpe=sentencepiece \
      --max-len-b 500 \
      --add-bos-token \
      --beam 1 \
      --buffer-size 1 \
      --image-feature-length 64 \
      --locate-special-token 1 \
      --batch-size 1 \
      --nbest 1 \
      --no-repeat-ngram-size 3 \
      --location-bin-size 32" > $LOG_DIR/kosmos2.log 2>&1 &

  echo $! > /tmp/kosmos2.pid
fi


send_to_discord "Kosmos2 Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/kosmos2/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"kosmos2"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,kosmos2"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"