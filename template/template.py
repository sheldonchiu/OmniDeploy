import os
import sys
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
}

def create_readme(title, description, filename="README.md"):
    """
    Create a README.md file with the given title and description.
    
    Args:
        title (str): The title for the README
        description (str): The description for the README
        filename (str): The output filename (default: README.md)
    """
    content = f"# {title}\n\n{description}\n"
    
    with open(filename, "w") as f:
        f.write(content)
    
    print(f"README.md created successfully with title: {title}")

if __name__ == "__main__":
    # Parse command-line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("--yaml_file", required=True, help="path to the YAML file")
    parser.add_argument("--ai", action="store_true", default=False, help="use AI model")
    args = parser.parse_args()
        
    # Load the YAML file
    with open(args.yaml_file) as f:
        yaml_data = yaml.safe_load(f)
    
    relative_path = Path(args.yaml_file).parent.resolve().relative_to(workspace_path/"configs")
    output_path = script_output_path / relative_path / yaml_data["name"]
    os.makedirs(output_path, exist_ok=True)
        
    # Load the YAML file as a Jinja2 template
    with open(args.yaml_file) as f:
        yaml_string = Template(f.read()).render(yaml_data)
        yaml_data = yaml.safe_load(yaml_string)

    for j2_file, output_filename in target_files.items():
        # Load the Jinja2 template file
        with open(os.path.join(current_path, j2_file)) as f:
            template = Template(f.read())

        # Render the template with the data
        result = template.render(yaml_data)

        # Write the output to the output file
        with open(output_path / output_filename, 'w') as f:
            f.write(result)
            
        if "extra_files"in yaml_data:
            for file, content in yaml_data["extra_files"].items():
                with open(output_path / file, 'w') as f:
                    f.write(content)
    
    if args.ai and not os.path.isfile(output_path / "README.md"):
        sys.path.append(str(workspace_path / "fun"))
        import auto_description as ai
        title = yaml_data['title']
        print(f"Preparing AI description for {yaml_data['title']}...")
        response = ai.run_flow(f"Write a short description for {title}.")
        desc = response['outputs'][0]['outputs'][0]['results']['message']['data']['text']
        create_readme(title, desc, output_path / "README.md")
        print(f"Description for {title} created successfully.")
        