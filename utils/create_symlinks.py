#!/usr/bin/env python3

import json
import os
import sys
import argparse
from pathlib import Path

def create_symlinks(json_file, source_base, dest_base):
    """
    Create symlinks according to the JSON configuration.
    
    Args:
        json_file: Path to the JSON configuration file
        source_base: Base path where source folders are located
        dest_base: Base path where symlinks will be created
    """
    # Ensure the base directories exist
    source_base = Path(source_base).resolve()
    dest_base = Path(dest_base).resolve()
    
    if not source_base.exists():
        print(f"Error: Source base directory {source_base} does not exist.")
        return False
    
    # Create destination directory if it doesn't exist
    os.makedirs(dest_base, exist_ok=True)
    
    # Load JSON configuration
    try:
        with open(json_file, 'r') as f:
            config = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON file: {e}")
        return False
    except FileNotFoundError:
        print(f"Error: Could not find JSON file {json_file}")
        return False
    
    # Process each entry in the configuration
    for key, value in config.items():
        source_dir = source_base / key
        
        # Handle both single path and list of paths
        if isinstance(value, list):
            # Create a directory for the key first
            os.makedirs(dest_base / key, exist_ok=True)
            
            # For list values, create symlinks to each subfolder
            for subfolder in value:
                dest_link = dest_base / key / subfolder
                source_path = source_base / subfolder
                
                create_single_symlink(source_path, dest_link)
        else:
            # For single values, create a direct symlink
            dest_link = dest_base / value
            create_single_symlink(source_dir, dest_link)
    
    return True

def create_single_symlink(source, dest):
    """Create a single symlink, handling existing links and directories."""
    # Ensure source exists
    if not source.exists():
        print(f"Warning: Source {source} does not exist. Creating directory.")
        os.makedirs(source, exist_ok=True)
    
    # Remove existing symlink or directory
    if dest.is_symlink():
        dest.unlink()
    elif dest.exists():
        print(f"Warning: {dest} already exists and is not a symlink. Skipping.")
        return
    
    # Create parent directories if they don't exist
    os.makedirs(dest.parent, exist_ok=True)
    
    # Create the symlink
    try:
        os.symlink(source, dest, target_is_directory=source.is_dir())
        print(f"Created symlink: {dest} -> {source}")
    except OSError as e:
        print(f"Error creating symlink {dest}: {e}")

def main():
    parser = argparse.ArgumentParser(description='Create symlinks based on JSON configuration.')
    parser.add_argument('json_file', help='Path to the JSON configuration file')
    parser.add_argument('source_base', help='Base directory where source folders are located')
    parser.add_argument('dest_base', help='Base directory where symlinks will be created')
    
    args = parser.parse_args()
    
    if create_symlinks(args.json_file, args.source_base, args.dest_base):
        print("Symlink creation completed successfully.")
    else:
        print("Symlink creation failed.")
        sys.exit(1)

if __name__ == "__main__":
    main()
