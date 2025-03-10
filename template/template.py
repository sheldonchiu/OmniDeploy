import os
import argparse
import yaml
from pathlib import Path
from jinja2 import Template

current_path = Path(__file__).parent.absolute()
workspace_path = current_path.parent
script_output_path = workspace_path / "scripts"

target_files = {
    "control.j2": "control.sh",
    "main.j2": "main.sh",
    "env.j2": ".env",
    # "start.j2": "start.sh",
}

if __name__ == "__main__":
    # Parse command-line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("--yaml_file", required=True, help="path to the YAML file")
    args = parser.parse_args()
        
    # Load the YAML file
    with open(args.yaml_file) as f:
        yaml_data = yaml.safe_load(f)
    
    relative_path = Path(args.yaml_file).parent.resolve().relative_to(workspace_path/"configs")
    output_path = script_output_path / relative_path / yaml_data["name"]
        
    # Load the YAML file as a Jinja2 template
    with open(args.yaml_file) as f:
        yaml_string = Template(f.read()).render(yaml_data)
        yaml_data = yaml.safe_load(yaml_string)

    for j2_file, output_filename in target_files.items():
        if j2_file == "start.j2" and "start_script" not in yaml_data:
            continue
        # Load the Jinja2 template file
        with open(os.path.join(current_path, j2_file)) as f:
            template = Template(f.read())

        # Render the template with the data
        result = template.render(yaml_data)

        # Write the output to the output file
        with open(os.path.join(output_path, output_filename), 'w') as f:
            f.write(result)