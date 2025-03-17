#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up SD webui infinite image browsing ###"
log "Setting up SD webui infinite image browsing"
if [[ "$REINSTALL_IMAGE_BROWSER" || ! -f "$VENV_DIR/image_browser.prepared" ]]; then

    TARGET_REPO_URL="https://github.com/zanllp/sd-webui-infinite-image-browsing.git" \
    TARGET_REPO_DIR=$REPO_DIR \
    UPDATE_REPO="auto" \
    TARGET_REPO_BRANCH="main" \
    prepare_repo
    rm -rf $VENV_DIR/image_browser-env
    
    echo "### Installing Python ###"
    
    $UV_INSTALL_DIR/uv venv --seed --python 3.10 $VENV_DIR/image_browser-env
    
    source $VENV_DIR/image_browser-env/bin/activate
    
    cd $REPO_DIR
    $UV_INSTALL_DIR/uv pip install -r requirements.txt
    
    touch $VENV_DIR/image_browser.prepared
else
    
    $UV_INSTALL_DIR/uv python install 
    source $VENV_DIR/image_browser-env/bin/activate
    
fi
log "Finished Preparing Environment for SD webui infinite image browsing"


if [[ -n "${IMAGE_BROWSER_KEY}" ]]; then
cat > $REPO_DIR/.env << EOF
IIB_SECRET_KEY=$IMAGE_BROWSER_KEY
# Configuring the server-side language for this extension,
# including the tab title and most of the server-side error messages returned. Options are 'zh', 'en', or 'auto'.
# If you want to configure the language for the front-end pages, please set it on the extension's global settings page.
IIB_SERVER_LANG=auto
EOF
fi


if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting SD webui infinite image browsing ###"
  log "Starting SD webui infinite image browsing"
  if [ -n IMAGE_OUTPUTS_DIR ]; then
      cd $IMAGE_OUTPUTS_DIR
  else
      cd $REPO_DIR
  fi
  PYTHONUNBUFFERED=1 service_loop "python $REPO_DIR/app.py --port 7002" > $LOG_DIR/image_browser.log 2>&1 &
  echo $! > /tmp/image_browser.pid
fi


send_to_discord "SD webui infinite image browsing Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/image-browser/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"image_browser"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,image_browser"
  fi
  bash $WORKING_DIR/utils/cloudflare_reload.sh
fi

echo "### Done ###"