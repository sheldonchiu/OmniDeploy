#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR

echo "### Command received ###"
file="/tmp/command.pid"
if [[ $1 == "reload" ]]; then
    log "Reloading Command Server"
    
    kill_pid /tmp/command.pid
    if [[ -n "${DISCORD_BOT}" ]]; then
      kill_pid /tmp/command_process.pid
    fi
    # Wait for 1s to avoid unexpected behavior
    sleep 1
    bash main.sh
    
elif [[ $1 == "start" ]]; then
    log "Starting Command Server"
    
    bash main.sh
    
elif [[ $1 == "stop" ]]; then
    log "Stopping Command Server"
    
    kill_pid /tmp/command.pid
    if [[ -n "${DISCORD_BOT}" ]]; then
      kill_pid /tmp/command_process.pid
    fi
    

else
  echo "Invalid argument"
fi

echo "### Done ###"