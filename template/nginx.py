import os
import argparse
from glob import glob
import yaml
from jinja2 import Template
from pathlib import Path

current_path = os.path.dirname(os.path.abspath(__file__))
output_file = Path(current_path).parent / "utils/nginx/default"

if __name__ == "__main__":
    # Load the YAML file
    targets = Path(current_path).parent / "configs/**/*.yaml"
    yaml_files = glob(str(targets), recursive=True)
    yaml_files.sort()

    # Load the YAML file as a Jinja2 template
    data = []
    for file in yaml_files:
        with open(file, 'r') as f:
            yaml_data = yaml.safe_load(f)
            if "expose" in yaml_data and yaml_data['expose']:
                if "name" not in yaml_data or "port" not in yaml_data:
                    print("Missing name or port for " + file)
                    continue
                output = {"name": yaml_data["name"], "port": yaml_data["port"]}
                output["nginx_override"] = (
                    yaml_data["nginx_override"] if "nginx_override" in yaml_data else None
                )
                output["extra"] = (
                    yaml_data["nginx_extra"] if "extra" in yaml_data else None
                )
                data.append(output)


    with open(os.path.join(current_path, 'nginx-site.j2')) as f:
        template = Template(f.read())
    result = template.render({'data': data})
    with open(output_file, "w") as f:
        f.write(result)
