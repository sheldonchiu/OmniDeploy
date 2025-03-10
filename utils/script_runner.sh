#!/usr/bin/env bash

# Script name: yaml-script-runner.sh

set -e  # Exit on error

DIR=$(dirname "$(realpath "$0")")
cd $DIR/..

# Colors for output
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# Config directory
CONFIG_DIR="configs"

# Function to capture ESC key
capture_esc() {
  read -rsn1 -t 0.1 key
  if [[ $key == $'\e' ]]; then
    return 0  # ESC was pressed
  fi
  return 1  # ESC was not pressed
}

# Function to wait for user to press Enter or ESC
wait_for_input() {
  echo -e "${YELLOW}Press Enter to continue or ESC to return to main menu...${NC}"
  while true; do
    read -rsn1 key
    if [[ $key == $'\e' ]]; then
      return 0  # ESC was pressed
    elif [[ $key == "" ]]; then
      return 1  # Enter was pressed
    fi
  done
}

# Function to display the main menu and get selection
show_main_menu() {
  echo -e "${BLUE}=== YAML Script Runner ===${NC}"
  
  # Use gum choose to create a top-level menu
  selected_option=$(gum choose "Run Scripts" "Run Status Monitor" "Configure Settings" "Help" "Exit")
  
  case "$selected_option" in
    "Run Scripts")
      run_scripts
      ;;
    "Run Status Monitor")
      run_status_monitor
      ;;
    "Configure Settings")
      configure_settings
      ;;
    "Help")
      show_help
      ;;
    "Exit")
      echo -e "${YELLOW}Exiting program. Goodbye!${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid option${NC}"
      ;;
  esac
}

# Function to run the status monitor
run_status_monitor() {
  echo -e "${BLUE}=== Status Monitor ===${NC}"
  
  if [ -f "utils/status_check.py" ]; then
    echo -e "${YELLOW}Starting status monitor...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop the monitor and return to the previous menu.${NC}"
    echo -e "${YELLOW}Press ESC at any time to return to the main menu.${NC}"
    echo
    
    # Trap Ctrl+C to return to menu instead of exiting script
    trap 'echo -e "\n${YELLOW}Monitor stopped. Returning to previous menu...${NC}"; sleep 1; return' INT
    
    # Run the status check script in the background with ESC key monitoring
    watch -n 1 "python utils/status_check.py"
    PID=$!
    
    # Check for ESC key while the python script is running
    while kill -0 $PID 2>/dev/null; do
      if capture_esc; then
        kill $PID 2>/dev/null
        echo -e "\n${YELLOW}Monitor stopped. Returning to main menu...${NC}"
        sleep 1
        return
      fi
      sleep 0.1
    done
    
    # Wait for the process to finish
    wait $PID
    
    # Reset trap
    trap - INT
    
    # Check if ESC was pressed to return immediately
    if capture_esc; then
      return
    fi
    
    # Wait for user to press Enter or ESC
    if wait_for_input; then
      return  # ESC was pressed, return immediately
    fi
  else
    echo -e "${RED}Error: Status check script not found at utils/status_check.py!${NC}"
    
    # Wait for user to press Enter or ESC
    if wait_for_input; then
      return  # ESC was pressed, return immediately
    fi
  fi
}

# Function to run scripts with organized folder structure
run_scripts() {
  echo -e "${BLUE}=== Run Scripts ===${NC}"

  # Check if config directory exists
  if [ ! -d "$CONFIG_DIR" ]; then
    echo -e "${RED}Error: Config directory '$CONFIG_DIR' not found!${NC}"
    
    # Wait for user to press Enter or ESC
    if wait_for_input; then
      return  # ESC was pressed, return immediately
    fi
    return 1
  fi

  # Group scripts by folder
  declare -A folders
  
  # Find all YAML files
  while IFS= read -r file; do
    if [ -f "$file" ]; then
      # Extract folder path relative to CONFIG_DIR
      rel_path="${file#$CONFIG_DIR/}"
      folder_path=$(dirname "$rel_path")
      
      # Skip files in deprecated folder or its subfolders
      if [[ "$rel_path" == deprecated/* ]]; then
        continue
      fi
      
      # Initialize array for this folder if it doesn't exist
      if [ -z "${folders[$folder_path]}" ]; then
        folders[$folder_path]=""
      fi
      
      # Add file to folder list
      if [ -z "${folders[$folder_path]}" ]; then
        folders[$folder_path]="$file"
      else
        folders[$folder_path]="${folders[$folder_path]}|$file"
      fi
    fi
  done < <(find "$CONFIG_DIR" -type f -name "*.yaml" -o -name "*.yml" | sort)
  
  if [ ${#folders[@]} -eq 0 ]; then
    echo -e "${RED}No YAML files found in '$CONFIG_DIR'!${NC}"
    
    # Wait for user to press Enter or ESC
    if wait_for_input; then
      return  # ESC was pressed, return immediately
    fi
    return 1
  fi

  # Arrays to store script information
  declare -a script_titles=()
  declare -a script_names=()
  declare -a all_choices=()
  
  # Process files by folder (keeping folder order)
  for folder in $(echo "${!folders[@]}" | tr ' ' '\n' | sort); do
    IFS='|' read -ra folder_files <<< "${folders[$folder]}"
    
    for file in "${folder_files[@]}"; do
      [ -z "$file" ] && continue
      
      title=$(grep "^title:" "$file" | cut -d ":" -f2- | sed 's/^ *//')
      name=$(grep "^name:" "$file" | cut -d ":" -f2- | sed 's/^ *//')
      
      if [ -n "$title" ] && [ -n "$name" ]; then
        # Store only the title for selection (without folder path)
        all_choices+=("$title")
        script_titles+=("$title")
        script_names+=("$name")
      fi
    done
  done

  if [ ${#all_choices[@]} -eq 0 ]; then
    echo -e "${RED}No valid scripts found in the YAML files!${NC}"
    
    # Wait for user to press Enter or ESC
    if wait_for_input; then
      return  # ESC was pressed, return immediately
    fi
    return 1
  fi

  echo -e "${YELLOW}Select scripts to run (use Tab or Ctrl+Space to select multiple, Enter to confirm):${NC}"
  echo -e "${YELLOW}Press ESC to return to main menu.${NC}"
  
  # Create a temporary file to store the selections
  temp_file=$(mktemp)
  
  # Use gum filter with --no-limit flag and output to temp file to preserve spaces
  # Note: gum already handles ESC key to exit
  gum choose --no-limit "${all_choices[@]}" > "$temp_file" || {
    rm "$temp_file"
    return  # User pressed ESC
  }
  
  # Check if any selections were made
  if [ ! -s "$temp_file" ]; then
    rm "$temp_file"
    echo -e "${YELLOW}No scripts selected. Returning to main menu.${NC}"
    sleep 1
    return 0
  fi

  # Build the comma-separated list of script names for selected titles
  selected_script_names=""
  
  # Display selected scripts
  echo -e "${GREEN}Selected scripts:${NC}"
  
  # Process each selected title line by line to preserve spaces
  while IFS= read -r selected_title; do
    echo -e "  - $selected_title"
    
    # Find the matching script name
    for i in "${!script_titles[@]}"; do
      if [ "${script_titles[$i]}" = "$selected_title" ]; then
        # Add to selected script names
        if [ -n "$selected_script_names" ]; then
          selected_script_names="$selected_script_names,${script_names[$i]}"
        else
          selected_script_names="${script_names[$i]}"
        fi
        break
      fi
    done
  done < "$temp_file"
  
  # Clean up temp file
  rm "$temp_file"
  
  # Set environment variable and run entry script
  export RUN_SCRIPT="$selected_script_names"
  
  echo -e "\n${YELLOW}Running with RUN_SCRIPT=$RUN_SCRIPT${NC}"
  echo -e "${YELLOW}Press ESC at any time to return to the main menu.${NC}"
  
  if [ -f "entry.sh" ]; then
    chmod +x entry.sh
    
    # Run entry.sh in the background with ESC key monitoring
    ./entry.sh &
    PID=$!
    
    # Check for ESC key while entry.sh is running
    while kill -0 $PID 2>/dev/null; do
      if capture_esc; then
        kill $PID 2>/dev/null
        echo -e "\n${YELLOW}Script execution stopped. Returning to main menu...${NC}"
        sleep 1
        return
      fi
      sleep 0.1
    done
    
    # Wait for the process to finish
    wait $PID
  else
    echo -e "${RED}Error: entry.sh script not found!${NC}"
    
    # Wait for user to press Enter or ESC
    if wait_for_input; then
      return  # ESC was pressed, return immediately
    fi
    return 1
  fi
  
  # Wait for user to press Enter or ESC
  if wait_for_input; then
    return  # ESC was pressed, return immediately
  fi
}

# Function to configure settings
configure_settings() {
  echo -e "${BLUE}=== Configure Settings ===${NC}"
  
  echo -e "${YELLOW}Current config directory: $CONFIG_DIR${NC}"
  echo -e "${YELLOW}Press ESC at any time to return to main menu.${NC}"
  
  echo -e "Enter new config directory path (or press Enter to keep current):"
  new_config_dir=$(gum input --placeholder "$CONFIG_DIR") || {
    echo -e "${YELLOW}Cancelled. Returning to main menu.${NC}"
    return  # User pressed ESC
  }
  
  if [ -n "$new_config_dir" ]; then
    CONFIG_DIR="$new_config_dir"
    echo -e "${GREEN}Config directory updated to: $CONFIG_DIR${NC}"
  else
    echo -e "${YELLOW}Config directory unchanged.${NC}"
  fi
  
  # Wait for user to press Enter or ESC
  if wait_for_input; then
    return  # ESC was pressed, return immediately
  fi
}

# Function to show help
show_help() {
  echo -e "${BLUE}=== Help ===${NC}"
  echo -e "This script allows you to run YAML-configured scripts through a menu interface."
  echo -e ""
  echo -e "${YELLOW}Main Menu Options:${NC}"
  echo -e "  ${GREEN}Run Scripts${NC}: Select and run one or more scripts"
  echo -e "  ${GREEN}Run Status Monitor${NC}: Start the status monitoring tool"
  echo -e "  ${GREEN}Configure Settings${NC}: Change configuration options like directory paths"
  echo -e "  ${GREEN}Help${NC}: Show this help information"
  echo -e "  ${GREEN}Exit${NC}: Exit the program"
  echo -e ""
  echo -e "${YELLOW}Navigation:${NC}"
  echo -e "  - Press ${GREEN}ESC${NC} at any time to return to the main menu"
  echo -e "  - Press ${GREEN}Enter${NC} to proceed or confirm selections"
  echo -e ""
  echo -e "${YELLOW}Script Selection:${NC}"
  echo -e "  - Scripts are listed by their titles in order based on folder structure"
  echo -e "  - The 'deprecated' folder is automatically skipped"
  echo -e "  - Use the arrow keys to navigate or type to search for specific scripts"
  echo -e "  - Titles with spaces are fully supported"
  echo -e ""
  echo -e "${YELLOW}Status Monitor:${NC}"
  echo -e "  - Runs the Python script at utils/status_check.py"
  echo -e "  - This is a long-running process that monitors system status"
  echo -e "  - Press Ctrl+C to stop the monitor and return to the previous menu"
  echo -e "  - Press ESC to stop the monitor and return to the main menu"
  echo -e ""
  echo -e "${YELLOW}Script Requirements:${NC}"
  echo -e "  - YAML files should include 'title', 'name' and optionally 'description'"
  echo -e "  - An 'entry.sh' script must exist in the current directory"
  echo -e ""
  
  # Wait for user to press Enter or ESC
  wait_for_input
}

# Main program loop
while true; do
  clear
  show_main_menu
done
