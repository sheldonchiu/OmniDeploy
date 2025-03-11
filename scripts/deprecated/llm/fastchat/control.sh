#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR

echo "### Command received ###"
file="/tmp/fastchat.pid"
if [[ $1 == "reload" ]]; then
    log "Reloading FastChat"
    
    if [[ -n $2 ]]; then
        case $2 in
            "controller")
                log "Stopping Fastchat controller"
                kill_pid "/tmp/fastchat_controller.pid"
                ;;
            "worker")
                log "Stopping Fastchat worker"
                kill_pid "/tmp/fastchat_worker.pid"
                ;;
            "server")
                log "Stopping Fastchat server"
                kill_pid "/tmp/fastchat_server.pid"
                ;;
            *)
                echo "Invalid argument. Usage: bash control.sh [reload|start|stop] [controller|worker|server]"
                exit 1
                ;;
        esac
        bash main.sh $2
    else
        kill_pid "/tmp/fastchat_server.pid"
        kill_pid "/tmp/fastchat_worker.pid"
        kill_pid "/tmp/fastchat_controller.pid"
        bash main.sh
    fi
    
elif [[ $1 == "start" ]]; then
    log "Starting FastChat"
    
    bash main.sh
    
elif [[ $1 == "stop" ]]; then
    log "Stopping FastChat"
    
    if [[ -n $2 ]]; then
        case $2 in
            "controller")
                log "Stopping Fastchat controller"
                kill_pid "/tmp/fastchat_controller.pid"
                ;;
            "worker")
                log "Stopping Fastchat worker"
                kill_pid "/tmp/fastchat_worker.pid"
                ;;
            "server")
                log "Stopping Fastchat server"
                kill_pid "/tmp/fastchat_server.pid"
                ;;
            *)
                echo "Invalid argument. Usage: bash control.sh [reload|start|stop] [controller|worker|server]"
                ;;
        esac
    else
        kill_pid "/tmp/fastchat_server.pid"
        kill_pid "/tmp/fastchat_worker.pid"
        kill_pid "/tmp/fastchat_controller.pid"
    fi
    

else
  echo "Invalid argument"
fi

echo "### Done ###"