#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR

echo "### Command received ###"
file="/tmp/kohya_ss.pid"
if [[ $1 == "reload" ]]; then
    log "Reloading Kohya SD Trainer"
    
    kill_pid $file
    sleep 1
    bash main.sh
    
elif [[ $1 == "start" ]]; then
    log "Starting Kohya SD Trainer"
    
    bash main.sh
    
elif [[ $1 == "stop" ]]; then
    log "Stopping Kohya SD Trainer"
        
    kill_pid $file
    

else
  echo "Invalid argument"
fi

echo "### Done ###"