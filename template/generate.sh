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

echo "Looking for YAML files in: ${YAML_DIR}"

# Process all YAML files in the configs directory
for yaml_file in "${YAML_DIR}"/*.yaml; do
    # Check if file exists and is a regular file
    if [[ -f "${yaml_file}" ]]; then
        filename=$(basename "${yaml_file}")
        echo "Processing YAML file: ${filename}"
        
        # Run the template script for each YAML file
        # Using the template script from the current script's directory
        python3 "${SCRIPT_DIR}/template.py" --yaml_file "${yaml_file}"
    fi
done

echo "All YAML files processed."

cd $current_dir
python3 nginx.py