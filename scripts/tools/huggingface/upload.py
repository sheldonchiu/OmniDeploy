import os
import sys
from huggingface_hub import login, HfApi

if __name__ == "__main__":
    
    login(token=os.environ['HUGGINGFACE_TOKEN'])
    api = HfApi()
    
    target_folder_path = os.environ.get('HF_TARGET_FOLDER_PATH', None)
    target_files = os.environ.get('HF_TARGET_FILES', None)
    target_repo = os.environ.get('HF_TARGET_REPO', None)
    target_repo_is_private = os.environ.get('HF_TARGET_REPO_PRIVATE', None)
    
    if target_repo is None:
        print("Please set HF_TARGET_REPO environment variable")
        sys.exit(1)
    else:
        api.create_repo(repo_id=target_repo, private=target_repo_is_private != None, exist_ok=True)
        
    if target_folder_path is not None:
        target_folder_path = target_folder_path.strip()
        api.upload_folder(
            folder_path=target_folder_path,
            repo_id=target_repo,
        )
    elif target_files is not None:
        target_files = target_files.split(',')
        for file in target_files:
            file = file.strip()
            api.upload_file(
            path_or_fileobj=file,
            path_in_repo=os.path.basename(file),
            repo_id=target_repo,
        )

