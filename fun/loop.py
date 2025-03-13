import os
import re
import mimetypes
from file_summary import summarize

def is_text_file(file_path, sample_size=8192):
    """
    Check if a file is a text file by:
    1. Checking its MIME type
    2. Reading a sample and trying to decode it as UTF-8
    """
    # First, check MIME type
    mime_type, _ = mimetypes.guess_type(file_path)
    if mime_type and not mime_type.startswith(('text/', 'application/json', 'application/xml')):
        return False
    
    # Read a sample of the file
    try:
        with open(file_path, 'rb') as f:
            sample = f.read(sample_size)
        
        # Try to decode as text
        sample.decode('utf-8')
        return True
    except UnicodeDecodeError:
        return False
    except Exception:
        return False

def remove_markdown_wrap(text):
    # Check if the text starts with ```markdown and ends with ```
    markdown_pattern = r'```markdown\s*(.*?)\s*```'
    match = re.search(markdown_pattern, text, re.DOTALL)
    if match:
        # Extract the content without the markdown wrapper
        return match.group(1).strip()
    else:
        # Return original text if no markdown wrapper is found
        return text

def process_directory(directory_path, output_file="README.md"):
    # Initialize mimetypes
    mimetypes.init()
    
    # Get list of all files in the directory that have an extension and are text files
    files = []
    skipped_files = []
    
    for f in os.listdir(directory_path):
        file_path = os.path.join(directory_path, f)
        # Check if it's a file, has an extension, and is readable text
        if (os.path.isfile(file_path) and 
            '.' in f and 
            f.rsplit('.', 1)[1] != '' and
            is_text_file(file_path)):
            files.append(f)
        elif os.path.isfile(file_path):
            skipped_files.append(f)
    
    print(f"Found {len(files)} readable text files, skipped {len(skipped_files)} files")
    
    with open(output_file, 'w') as readme:
        readme.write("# File Summaries\n\n")
        
        for i, file in enumerate(files):
            file_path = os.path.join(directory_path, file)
            print(f"Processing {i+1}/{len(files)}: {file}")
            
            try:
                # Get summary
                response = summarize(file_path)
                result = response['outputs'][0]['outputs'][0]['results']['message']['data']['text']
                result = remove_markdown_wrap(result)
                
                # Write to README
                readme.write(f"## {file}\n\n")
                readme.write(result)
                
                # Add separator line between summaries, but not after the last one
                if i < len(files) - 1:
                    readme.write("\n\n---\n\n")
                
            except Exception as e:
                error_message = f"Error processing {file}: {str(e)}"
                print(error_message)
                readme.write(f"## {file}\n\n")
                readme.write(f"*{error_message}*")
                
                # Add separator line between summaries
                if i < len(files) - 1:
                    readme.write("\n\n---\n\n")
        
        # Add a section about skipped files
        if skipped_files:
            readme.write("\n\n---\n\n")
            readme.write("## Skipped Files\n\n")
            readme.write("The following files were skipped as they appear to be binary or non-text files:\n\n")
            for skipped in skipped_files:
                readme.write(f"- {skipped}\n")
    
    print(f"Summary complete. Results saved to {output_file}")

if __name__ == "__main__":
    # Replace with your target directory
    target_directory = "/Users/sheldon/Documents/Ultimate-Paperspace-Template/utils"
    process_directory(target_directory)
