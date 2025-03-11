#!/bin/bash

# Define a function to echo a message and exit
error_exit() {
  echo "$1" >&2
  exit 1
}

# Define a recursive function to kill all descendant processes
kill_descendants() {
  local parent_pid="$1"
  local child_pids=$(pgrep -P "${parent_pid}")
  for child_pid in ${child_pids}; do
    echo "Killing descendant processes of PID ${parent_pid}: ${child_pids}"
    kill_descendants "${child_pid}"
  done
  if [[ -n "${parent_pid}" ]]; then
    kill -TERM "${parent_pid}" >/dev/null 2>&1
  fi

}

kill_pid() {
  # Read the pid from a file
  if [[ -f $1 ]]; then
    pid=$(cat $1)
  elif [[ $1 =~ ^[0-9]+$ ]]; then
    pid=$1
  else
    log "Error: PID file $1 not found!"
    return
  fi

  # Check if the process has exited
  if ! kill -0 $pid 2>/dev/null; then
    echo "Error: Process $pid has already exited."
    return
  fi

  # Kill the process
  kill_descendants $pid

  echo "Process $pid has been killed."
}

check_if_running() {
  if [[ -f "$1" ]]; then
    pid=$(cat "$1")
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  else
    log "Error: PID file $1 not found!"
  fi
  return 1
}

format_log() {
    # Get the current date and time in ISO format
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Output the log message
    printf "[$timestamp] $1\n"
}

log() {
    echo "$(format_log "$1")"
}

send_to_discord() {
  output=$(format_log "$1")

  echo "$output"
  if [[ -n $DISCORD_WEBHOOK_URL ]]; then
    # Send the message using curl
    curl -H "Content-Type: application/json" \
        -X POST \
        -d "{\"content\":\"$output\"}" \
        "${DISCORD_WEBHOOK_URL}" 2>&1 > /dev/null
  fi
}

prepare_repo(){
  if [[ -n $TARGET_REPO_DIR ]]; then
      if [[ ! -d "$TARGET_REPO_DIR/.git" ]]; then
          mkdir -p "$TARGET_REPO_DIR"
          cd "$TARGET_REPO_DIR"
          git init > /dev/null
          git remote add origin $TARGET_REPO_URL > /dev/null
          git fetch > /dev/null
          if [[ -n $TARGET_REPO_BRANCH ]]; then
              git checkout -t origin/$TARGET_REPO_BRANCH -f > /dev/null
          else
              git checkout -t origin/master -f > /dev/null
          fi
      fi

      if [[ $UPDATE_REPO == "auto" ]]; then
          log "Updating Repo $TARGET_REPO_DIR ..."
          cd $TARGET_REPO_DIR
          git fetch > /dev/null
          git checkout $TARGET_REPO_BRANCH > /dev/null
          git pull > /dev/null
      elif [[ $UPDATE_REPO == "commit" ]]; then
          log "Updating $TARGET_REPO_DIR to commit $UPDATE_REPO_COMMIT..."
          cd $TARGET_REPO_DIR
          git fetch > /dev/null
          git checkout $UPDATE_REPO_COMMIT > /dev/null
      fi
  fi
}

prepare_link(){
  if [[ $# -gt 0 ]]; then
      for symlink in "$@"; do
          src="${symlink%%:*}"
          dests="${symlink#*:}"

          IFS=',' read -ra dest_array <<< "$dests"

          mkdir -p $src
          for dest in "${dest_array[@]}"; do
              rm -rf $dest
              ln -s $src $dest
              log "$(realpath $dest) -> $dest"
          done
      done
  fi
}

download_from_hf() {
  model_hub="$1"
  model_name="$2"
  TARGET_REPO_DIR="$MODEL_DIR/$model_name" \
    TARGET_REPO_BRANCH="$3" \
    TARGET_REPO_URL="https://huggingface.co/$model_hub/$model_name" \
    prepare_repo
}

minio_sync(){
  /tmp/minio-binaries/mc mirror --watch --overwrite --quiet $S3_MIRROR_PATH dst/$S3_MIRROR_TO_BUCKET ${EXTRA_MINIO_ARGS} > $LOG_DIR/minio_mirror_root.log 2>&1 &
  echo $! > /tmp/minio_root.pid

  for item in "$S3_MIRROR_PATH"/*
  do
      # Check if the item is a symlink and a directory
      if [[ -L "$item" && -d "$item" ]]
      then
          # Process the symlinked folder
          log "Processing symlinked folder: $item"
          folder_name=$(basename $item)
          /tmp/minio-binaries/mc mirror --watch --overwrite --quiet $item dst/$S3_MIRROR_TO_BUCKET/$folder_name ${EXTRA_MINIO_ARGS} > $LOG_DIR/minio_mirror_$folder_name.log 2>&1 &
          echo $! > /tmp/minio_$folder_name.pid
    fi
  done
}

llm_model_downlaod(){
  current_dir=$(dirname "$(realpath "$0")")
  chmod +x $current_dir/hfdownloader

  if ! [ -v "MODEL_DIR" ]; then
      source $current_dir/../.env
      export MODEL_DIR="$DATA_DIR/llm-models"
  fi

  echo "### Downloading Models ###"
  IFS=',' read -ra models <<< "$LLM_MODEL_TO_DOWNLOAD"
  for model in "${models[@]}"
  do
      $current_dir/hfdownloader -m $model -s $MODEL_DIR 2>&1 > /dev/null
  done

  echo "### Finished Model Download ###"
}

service_loop(){
  set +e

  COMMAND="$1"

  while true; do
    eval "$COMMAND" &
    PID=$!
    log "Started $COMMAND with PID $PID"

    wait $PID

    # Check the exit status
    if [ $? -eq 0 ]; then
      # Process exited successfully, break out of the loop
      log "Process exited successfully"
      break
    else
      # Process exited with an error, wait for a while and restart
      log "Process exited with an error, restarting in 5 seconds"
      sleep 5
    fi
  done
}
