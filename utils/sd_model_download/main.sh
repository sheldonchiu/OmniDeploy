#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
source $current_dir/../helper.sh

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR

echo "### Setting up Model Download ###"
if ! dpkg -s aria2 >/dev/null 2>&1; then
    apt-get install -qq aria2 -y > /dev/null
fi

MODULES=("requests" "gdown" "bs4" "python-dotenv")
# Loop through the modules and check if they are installed
for module in "${MODULES[@]}"; do
    if ! pip show $module >/dev/null 2>&1; then
        # Module is not installed, install it with pip
        echo "Module $module is not installed. Installing it now..."
        pip install $module
    fi
done

if ! [ -v "MODEL_DIR" ]; then
    source $WORKING_DIR/.env
    export MODEL_DIR="$DATA_DIR/models"
fi
# This only happen when directly using this script
if ! [ -v "MODEL_LIST" ]; then
    env | grep -v '^_' | sed 's/\([^=]*\)=\(.*\)/\1='\''\2'\''/' > $current_dir/.env
fi

echo "### Downloading Models ###"

python $current_dir/download_model.py
echo "### Finished Model Download ###"