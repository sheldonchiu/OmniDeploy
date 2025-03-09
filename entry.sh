#!/bin/bash
# Don't exit on error

function source_env_file() {
  if [[ -e ".env" ]]; then
    source ".env"
  fi
}

function check_required_env_vars() {
  local required_vars=($(echo "$REQUIRED_ENV" | tr ',' '\n'))
  local missing_vars=()
  for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
      missing_vars+=("$var")
    fi
  done
  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo "The following required environment variables are missing: ${missing_vars[*]}"
    return 1
  fi
  return 0
}

export SCRIPT_ROOT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
cd $SCRIPT_ROOT_DIR
source_env_file

# Prepare Path (for local install)
mkdir -p $DATA_DIR
mkdir -p $WORKING_DIR
mkdir -p $ROOT_REPO_DIR
mkdir -p $VENV_DIR
mkdir -p $LOG_DIR

echo "Installing common dependencies"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y curl jq git-lfs ninja-build \
    aria2 zip python3-venv python3-dev python3.10 \
    python3.10-venv python3.10-dev python3.10-tk libgl1 libglib2.0-0 > /dev/null

# Add alias to check the status of the web app
chmod +x $WORKING_DIR/utils/status_check.py
echo "alias status='watch -n 1 /$WORKING_DIR/utils/status_check.py'" >> ~/.bashrc

# Use Nginx to expose web app in Paperspace
apt-get install -qq -y nginx > /dev/null
cp /$WORKING_DIR/utils/nginx/default /etc/nginx/sites-available/default
cp /$WORKING_DIR/utils/nginx/nginx.conf /etc/nginx/nginx.conf
/usr/sbin/nginx

# Read the RUN_SCRIPT environment variable
run_script="$RUN_SCRIPT"

# Separate the variable by commas
IFS=',' read -ra scripts <<< "$run_script"

# Prepare required path
mkdir -p $IMAGE_OUTPUTS_DIR
if [[ ! -d $WORKING_DIR/image_outputs ]]; then
  ln -s $IMAGE_OUTPUTS_DIR $WORKING_DIR/image_outputs
fi

# Loop through each script and execute the corresponding case
echo "Starting script(s)"

for script in "${scripts[@]}"
do
    cd "$SCRIPT_ROOT_DIR" || exit 1
    
    # Search for the script directory recursively
    script_dir=$(find . -type d -name "$script")
    
    if [[ -z "$script_dir" ]]; then
        echo "Script folder $script not found, skipping..."
        continue
    fi
    
    # Change to the found directory
    cd "$script_dir" || continue
    
    source_env_file
    
    if ! check_required_env_vars; then
        echo "One or more required environment variables are missing."
        continue
    fi
    
    bash control.sh reload
done

echo "All scripts executed."
