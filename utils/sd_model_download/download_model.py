# from https://github.com/Engineer-of-Stuff/stable-diffusion-paperspace
import re
import requests
import gdown
import json
from bs4 import BeautifulSoup
import os
from dotenv import load_dotenv

load_dotenv()

model_storage_dir = os.environ['MODEL_DIR']
hf_token = os.environ.get('HF_TOKEN', None)
user_agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36'

def is_url(url_str):
    return re.search(r'https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9]+\.[^\s]{2,}|www\.[a-zA-Z0-9]+\.[^\s]{2,}', url_str)

def dl_web_file(web_dl_file, filename=None,  token=None):
    web_dl_file = is_url(web_dl_file)[0] # clean the URL string
    filename_cmd = f'--out="{filename}"' if filename else ''
    token_cmd = f"--header='Authorization: Bearer {token}'" if token else ''
    # We're going to use aria2 to split the download into threads which will allow us to download
    # the file very fast even if the site serves the file slow.
    command = f'''aria2c {token_cmd} --file-allocation=none -c -x 16 -s 16 --summary-interval=0 --console-log-level=warn --continue --user-agent "{user_agent}" {filename_cmd} "{web_dl_file}" '''
    os.system(command)
    
def downlaod_model(model_uri):
    model_uri = model_uri.strip()
    headers={'User-Agent': user_agent}
    magnet_match = re.search(r'magnet:\?xt=urn:btih:[\-_A-Za-z0-9&=%.]*', model_uri)
    civitai_match = re.search(r'^https?:\/\/(?:www\.|(?!www))civitai\.com\/models\/\d*\/.*?$', model_uri)
    web_match = is_url(model_uri)

    if magnet_match:
        bash_var = magnet_match[0]
        command = f'''aria2c --seed-time=0 --max-overall-upload-limit=1K --bt-max-peers=120 --summary-interval=0 --console-log-level=warn --file-allocation=none "{bash_var}"'''
        os.system(command)
        # clean exit here
    elif 'https://huggingface.co/' in model_uri:
        from urllib.parse import urlparse
        filename = os.path.basename(urlparse(model_uri.replace('/blob/', '/resolve/')).path)
        if hf_token:
            headers['Authorization'] = f'Bearer {hf_token}'
        response = requests.head(model_uri, allow_redirects=True, headers=headers)
        if response.status_code == 401:
            print('Huggingface token is invalid or not provided, please check your HF_TOKEN environment variable.')
        else:
            dl_web_file(model_uri.replace('/blob/', '/resolve/'), filename, token=hf_token)
            # clean exit here
    elif 'https://drive.google.com' in model_uri:
        gdrive_file_id, _ = gdown.parse_url.parse_url(model_uri)
        gdown.download(f"https://drive.google.com/uc?id={gdrive_file_id}&confirm=t")
        # clean exit here
    elif civitai_match:
        if not is_url(civitai_match[0]):
            print('URL does not match known civitai.com pattern.')
            # clean exit here
        else:
            soup = BeautifulSoup(requests.get(model_uri, headers=headers).text, features="html.parser")
            data = json.loads(soup.find('script', {'id': '__NEXT_DATA__'}).text)
            model_data = data["props"]["pageProps"]["trpcState"]["json"]["queries"][0]["state"]["data"]
            latest_model = model_data['modelVersions'][0]
            latest_model_url = f"https://civitai.com/api/download/models/{latest_model['id']}"
            print('Downloading model:', model_data['name'])
            
            # Download the description to a markdown file next to the checkpoint
            # desc = markdownify(model_data['description'])
            # req = urllib.request.Request(latest_model_url, data=None, headers={'User-Agent': user_agent})
            # content_disp = urllib.request.urlopen(req).getheader('Content-Disposition')
            # if content_disp:
            #     filename = Path(re.match(r'attachment; filename="(.*?)"', content_disp)[1]).stem
            #     with open(Path(model_storage_dir, f'{filename}.md'), 'w') as file:
            #         file.write(f"# {model_data['name']}\n")
            #         file.write(f'Original CivitAI URL: {model_uri}\n\n<br>\n\n')
            #         file.write(desc)
            # else:
            #     print('Failed to get filename of checkpoint for markdown file')
            dl_web_file(latest_model_url)
            # clean exit here
    elif web_match:
        # Always do the web match last
        with requests.get(web_match[0], allow_redirects=True, stream=True, headers=headers) as r:
            # Uing GET since some servers respond differently to HEAD.
            # Using `with` so we can close the connection and not download the entire file.
            response = r
            r.close()
        if response.headers.get('content-type') or response.headers.get('content-disposition'):
            if 'octet-stream' in response.headers.get('content-type', '') or 'attachment' in response.headers.get('content-disposition', ''):
                dl_web_file(model_uri)
                # clean exit here
            else:
                print('Required HTTP headers are incorrect. One of these needs to be correct:', end='\n\n')
                print('Content-Type:', response.headers['content-type'].split(";")[0] if response.headers.get('content-type') else 'None')
                print('Must be "application/octet-stream"', end='\n\n')
                print('Content-Disposition:', response.headers['content-disposition'] if response.headers.get('content-disposition') else 'None')
                print('Must start with "attachment;"')
                # clean exit here
        else:
            print('Required HTTP headers are missing. You need at lease one of these:', end='\n\n')
            print('Content-Type:', response.headers['content-type'].split(";")[0] if response.headers.get('content-type') else 'None')
            print('Must be "application/octet-stream"', end='\n\n')
            print('Content-Disposition:', response.headers['content-disposition'] if response.headers.get('content-disposition') else 'None')
            print('Must start with "attachment;"')
    else:
        print('Could not parse your URI.')
        # clean exit here

def prepare_folder(name):
    os.makedirs(f"{model_storage_dir}/{name}",exist_ok=True)
    os.chdir(f"{model_storage_dir}/{name}")  

prepare_folder("StableDiffusion")
model_list = os.environ.get('MODEL_LIST', "").split(',')
for uri in model_list:
    if uri != '':
        downlaod_model(uri)

prepare_folder("Unet")
model_list = os.environ.get('UNET_LIST', "").split(',')
for uri in model_list:
    if uri != '':
        downlaod_model(uri)

prepare_folder("TextEncoder")
model_list = os.environ.get('TEXT_ENCODER_LIST', "").split(',')
for uri in model_list:
    if uri != '':
        downlaod_model(uri)

prepare_folder("Lora")
lora_list = os.environ.get('LORA_LIST', "").split(',')
for uri in lora_list:
    if uri != '':
        downlaod_model(uri)
        
prepare_folder("IpAdapter")
lora_list = os.environ.get('IPADAPTER_LIST', "").split(',')
for uri in lora_list:
    if uri != '':
        downlaod_model(uri)

prepare_folder("ControlNet")
controlnet_list = os.environ.get('CONTROLNET_LIST', "").split(',')
for uri in controlnet_list:
    if uri != '':
        downlaod_model(uri)

prepare_folder("VAE")
vae_list = os.environ.get('VAE_LIST', "").split(',')
for uri in vae_list:
    if uri != '':
        downlaod_model(uri)
        
prepare_folder("TextualInversion") 
embedding_list = os.environ.get('EMBEDDING_LIST', "").split(',')
for uri in embedding_list:
    if uri != '':
        downlaod_model(uri)
        
prepare_folder("ESRGAN") 
upscaler_list = os.environ.get('ESRGAN_LIST', "").split(',')
for uri in upscaler_list:
    if uri != '':
        downlaod_model(uri)

prepare_folder("RealESRGAN") 
upscaler_list = os.environ.get('RealESRGAN_LIST', "").split(',')
for uri in upscaler_list:
    if uri != '':
        downlaod_model(uri)
        
prepare_folder("SwinIR") 
upscaler_list = os.environ.get('SwinIR_LIST', "").split(',')
for uri in upscaler_list:
    if uri != '':
        downlaod_model(uri)