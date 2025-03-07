#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR

echo "### Command received ###"
file="/tmp/cloudflared.pid"
if [[ $1 == "reload" ]]; then
    log "Reloading Cloudflare Tunnel"
    
    # Kill all and restart is not a good idea, only start tunnel if it's not running
    if [[ $CF_TOKEN == "quick" ]]; then
      bash main.sh
    fi
    
elif [[ $1 == "start" ]]; then
    log "Starting Cloudflare Tunnel"
    
    bash main.sh
    
elif [[ $1 == "stop" ]]; then
    log "Stopping Cloudflare Tunnel"
    
    if [[ -n $2 ]]; then
        log "Stopping Cloudflare tunnel for $2"
        kill_pid /tmp/cloudflared_$2.pid
    else
      log "Stopping all Cloudflare tunnel(s)"
      for file in /tmp/cloudflared_*.pid; do
          kill_pid $file
      done
    fi
    

else
  echo "Invalid argument"
fi

echo "### Done ###"