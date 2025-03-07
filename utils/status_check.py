#!/usr/local/bin/python
import os
import psutil
import subprocess

try:
    from prettytable import PrettyTable
except ImportError:
    # Use subprocess to run the pip command
    subprocess.check_call(['pip', 'install', 'prettytable'])
    from prettytable import PrettyTable


# Function to check if a process is running
def is_process_running(pid):
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False
    
def get_base_url():
    base_url = os.environ.get('PAPERSPACE_FQDN', "")
    if base_url == "":
        base_url = os.environ.get("PUBLIC_IPADDR", "")
        base_url += ":" +os.environ.get("VAST_TCP_PORT_8888", "")
    
    return base_url
        
    
def print_nvidia_smi_output():
    result = subprocess.run(['nvidia-smi'], capture_output=True, text=True)
    output = result.stdout
    print(output)

# Find files matching the pattern *.pid in /tmp
pid_files = [f for f in os.listdir('/tmp') if f.endswith('.pid') and 'minio' not in f]

# Initialize the table
table = PrettyTable()
table.field_names = ['Program', 'Running', "URL"]

running = "Completed"
# Get a list of all running processes
all_processes = psutil.process_iter()
# Check if the target process is still running
for proc in all_processes:
    try:
        # Get process information as a Process object
        pinfo = proc.as_dict(attrs=['pid', 'cmdline'])
        # Check if the process command line matches "bash entry.sh"
        if pinfo['cmdline'] and " ".join(pinfo['cmdline']) == "bash entry.sh":
            # The process is still running
            running = True
            break
    except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
        pass  # Ignore errors when accessing process information
table.add_row(["Start script", running, ""])

# Process each pid file
base_url = get_base_url()
for pid_file in pid_files:
    # Read the PID from the file
    with open(os.path.join('/tmp', pid_file), 'r') as f:
        pid = int(f.read().strip())

    # Check if the process is running
    
    running = is_process_running(pid)
    
    # host_file = os.path.join('/tmp', pid_file.replace('.pid', '.host'))
    # if os.path.isfile(host_file):
    #     with open(host_file, 'r') as f:
    #         host = f"https://{f.read().strip()}"
    # else:
    #     host = ""
    host = ""
    if running:
        service_name = os.path.splitext(pid_file)[0]
        host = f"https://{base_url}/{service_name.replace('_', '-')}/"

    # Add a row to the table
    table.add_row([pid_file.replace('.pid', ''), running, host])

print(table)
print("\n\n")
print_nvidia_smi_output()