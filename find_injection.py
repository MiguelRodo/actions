import os
import yaml

def check_run_injection(data, filepath):
    if isinstance(data, dict):
        for key, value in data.items():
            if key == 'run' and isinstance(value, str):
                if '${{' in value:
                    if 'inputs.' in value or 'env.' in value or 'github.' in value:
                        print(f"File {filepath} has potential injection in run step: {value.strip()[:100]}")
            else:
                check_run_injection(value, filepath)
    elif isinstance(data, list):
        for item in data:
            check_run_injection(item, filepath)

for root, dirs, files in os.walk('.'):
    for file in files:
        if file.endswith('action.yml') or file.endswith('workflow.yml'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                try:
                    content = yaml.safe_load(f)
                    check_run_injection(content, filepath)
                except Exception as e:
                    print(f"Error parsing {filepath}: {e}")
