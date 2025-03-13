#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

# Path to the configs directory (one level up from script directory, then into configs)
YAML_DIR="${SCRIPT_DIR}/../configs"

# Check if the YAML directory exists
if [[ ! -d "${YAML_DIR}" ]]; then
    echo "Error: YAML directory '${YAML_DIR}' not found!"
    exit 1
fi

# Parse command line arguments
USE_AI=false
for arg in "$@"; do
  if [[ "$arg" == "--ai" ]]; then
    USE_AI=true
  fi
done

echo "Looking for YAML files in: ${YAML_DIR}"

# Process all YAML files in the configs directory
for yaml_file in "${YAML_DIR}"/**/*.yaml; do
    # Skip files in deprecated folder or its subfolders
    if [[ "$yaml_file" == */deprecated/* ]]; then
    continue
    fi
    # Check if file exists and is a regular file
    if [[ -f "${yaml_file}" ]]; then
        filename=$(basename "${yaml_file}")
        echo "Processing YAML file: ${filename}"
        
    # Build command with or without --ai flag
    if [[ "$USE_AI" == true ]]; then
        uv run "${SCRIPT_DIR}/template.py" --yaml_file "${yaml_file}" --ai
    else
      uv run "${SCRIPT_DIR}/template.py" --yaml_file "${yaml_file}"
    fi
    fi
done

echo "All YAML files processed."

cd $SCRIPT_DIR
echo "Generating proxy config"
uv run createCaddyfile.py

echo "Done"
