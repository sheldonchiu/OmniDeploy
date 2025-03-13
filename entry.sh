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
mkdir -p $ROOT_REPO_DIR/settings
mkdir -p $VENV_DIR
mkdir -p $LOG_DIR

if [[ ! -f "$VEMV/prepared" ]]; then

  echo "Installing common dependencies"
  apt-get update -qq
  apt-get install -y curl jq git-lfs ninja-build gettext-base \
      aria2 zip libgl1 libglib2.0-0 > /dev/null

  # Install UV
  echo "Installing UV"
  curl -LsSf https://astral.sh/uv/0.6.5/install.sh | sh > /dev/null

  # install gum
  mkdir -p /etc/apt/keyrings
  # Download and add the GPG key, skipping if it already exists
  if [ ! -f /etc/apt/keyrings/charm.gpg ]; then
    curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg > /dev/null
  fi

  # Add the repository to sources list if not already added
  if [ ! -f /etc/apt/sources.list.d/charm.list ]; then
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | tee /etc/apt/sources.list.d/charm.list > /dev/null
  fi
  apt-get -qq update && apt-get install gum > /dev/null

  # Add alias to check the status of the web app
  chmod +x $WORKING_DIR/utils/script_runner.sh
  chmod +x $WORKING_DIR/utils/status_check.py
  echo "alias status='watch -n 1 $WORKING_DIR/utils/status_check.py'" >> ~/.bashrc
  echo "alias gui='bash $WORKING_DIR/utils/script_runner.sh'" >> ~/.bashrc
  source ~/.bashrc

  # Use Caddy to expose web app
  echo "Installing Caddy Proxy"
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl > /dev/null
  
  if [ ! -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg ]; then
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' |  gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg > /dev/null
  fi

  if [ ! -f /etc/apt/sources.list.d/caddy-stable.list ]; then
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null
  fi
  apt-get -qq update
  apt-get install -y caddy > /dev/null

  envsubst '$CADDY_IP $CADDY_PORT $LOG_DIR' < $WORKING_DIR/scripts/Caddyfile > /etc/caddy/Caddyfile

  # Check if caddy is already running and reload, otherwise start it
  if pgrep caddy > /dev/null; then
      /usr/bin/caddy reload --config /etc/caddy/Caddyfile >/dev/null 2>&1
  else
      /usr/bin/caddy start --config /etc/caddy/Caddyfile  --pidfile /tmp/caddy.pid > /dev/null 2>&1
  fi

fi 

touch $VEMV/prepared

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
