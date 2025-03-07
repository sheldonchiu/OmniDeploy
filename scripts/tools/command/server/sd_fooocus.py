from typing import Optional
from share import *
from db import Task
from auth import authenticate
from gradio_client import Client
from pydantic import BaseModel
from playhouse.shortcuts import model_to_dict
from fastapi import Depends, APIRouter
from fastapi.responses import FileResponse

from utils import download_image_as_base64

import logging

logger = logging.getLogger(__name__)


router = APIRouter()

image_fields = ['upscale_image', 'image_prompt_1', 'image_prompt_2', 'image_prompt_3', 'image_prompt_4']


class Base(BaseModel):
    prompt: str = ""
    negative_prompt: str = "low quality, bad hands, bad eyes, cropped, missing fingers, extra digit"
    positive_prompt_strength: float = 1.5
    negative_prompt_strength: float = 0.8
    guidance_end_at_step: float = 0.3
    cfg_scale: float = 7.0
    mimick_cfg: float = 7.0
    
    image_styles: list[str] = ["Fooocus Sharp", "Fooocus Enhance", "Fooocus V2"]
    
    performance: str = "Speed"
    resolution: str = "1024×1024"
    image_number: int = 1
    random_seed: bool = True
    seed: int = -1
    
    sd_model_checkpoint: str = "sd_xl_base_1.0_0.9vae.safetensors"
    sd_refiner_checkpoint: str = "sd_xl_refiner_1.0_0.9vae.safetensors"
    sd_lora_1: str = "sd_xl_offset_example-lora_1.0.safetensors"
    sd_lora_1_weight: float = 0.5
    sd_lora_2: str = "None"
    sd_lora_2_weight: float = -2
    sd_lora_3: str = "None"
    sd_lora_3_weight: float = -2
    sd_lora_4: str = "None"
    sd_lora_4_weight: float = -2
    sd_lora_5: str = "None"
    sd_lora_5_weight: float = -2
    
    sampling_sharpness: float = 2.0
    sampler: str = "dpmpp_2m_sde_gpu"
    scheduler: str = "karras"
    forced_sampling_step: float = -1
    forced_refiner_switch_step: float = -1
    forced_generating_width: float = -1
    forced_generating_height: float = -1
    forced_denoising_strength_vary: float = -1
    forced_denoising_strength_upscale: float = -1
    mix_image_prompt_vary_upscale: bool = False
    mix_image_prompt_inpaint: bool  = False
    debug_preprocessor_control_nets: bool  = False
    softness_of_control_net: float = 0.25
    canny_low_threshold: int = 64
    canny_high_threshold: int = 128
    inpaint_engine: str = "v1"
    refiner_swap_method: str = "joint"
    
    freeu: bool = False
    backbone_scale_f_1: float = 1.01
    backbone_scale_f_2: float = 1.02
    skip_scale_f_1: float = 0.99
    skip_scale_f_2: float = 0.95
    
    enhance_image: bool = False
    tab: str = "uov"
    variation_or_upscale: str = "Disabled"
    upscale_image: Optional[str] = None

    outpaint_image: Optional[str] = None
    outpaint_mode: list[str] = []
    
    image_prompt_1: Optional[str] = None
    image_prompt_type_1: str = "Image Prompt"
    image_prompt_stop_at_1: float = 0.5
    image_prompt_weight_1: float = 0.6
    image_prompt_2: Optional[str] = None
    image_prompt_type_2: str = "Image Prompt"
    image_prompt_stop_at_2: float = 0.5
    image_prompt_weight_2: float = 0.6
    image_prompt_3: Optional[str] = None
    image_prompt_type_3: str = "Image Prompt"
    image_prompt_stop_at_3: float = 0.5
    image_prompt_weight_3: float = 0.6
    image_prompt_4: Optional[str] = None
    image_prompt_type_4: str = "Image Prompt"
    image_prompt_stop_at_4: float = 0.5
    image_prompt_weight_4: float = 0.6
    
    


def save_result(task, *result):
    logger.info("Saving result for task %s", task.id)

    output = []
    images = result[2]["value"]
    for image in images:
        output.append(image["name"].replace(gradio_output_root_path, ""))

    task.status = "Done"
    task.result = output
    task.save()


def process_t2i(task: Task):
    config = task.config
    client = Client(
        f"{base_url}:{fooocus_port}{fooocus_subfoler}",
        output_dir=gradio_output_root_path,
        serialize=False,
    )
    if config['seed'] == -1:
        seed = client.predict(config["random_seed"], config["seed"], fn_index=21)
        task.config['seed'] = seed
        task.save()
    else:
        seed = config['seed']
        
        
    image_dict = {}
    for field in image_fields:
        url = config[field]
        if url:
            if url.startswith("http"):
                image_dict[field] = download_image_as_base64(url)
            else:
                image_dict[field] = url
        else:
            image_dict[field] = None

    client.predict(
        config['positive_prompt_strength'],
        config['negative_prompt_strength'],
        config['guidance_end_at_step'],
        config['mimick_cfg'],
        config['sampler'],  # str (Option from: ['euler', 'euler_ancestral', 'heun', 'dpm_2', 'dpm_2_ancestral', 'lms', 'dpm_fast', 'dpm_adaptive', 'dpmpp_2s_ancestral', 'dpmpp_sde', 'dpmpp_sde_gpu', 'dpmpp_2m', 'dpmpp_2m_sde', 'dpmpp_2m_sde_gpu', 'dpmpp_3m_sde', 'dpmpp_3m_sde_gpu', 'ddpm', 'ddim', 'uni_pc', 'uni_pc_bh2']) in 'Sampler' Dropdown component
        config['scheduler'],  # str (Option from: ['normal', 'karras', 'exponential', 'sgm_uniform', 'simple', 'ddim_uniform']) in 'Scheduler' Dropdown component
        config['forced_sampling_step'],
        config['forced_refiner_switch_step'],
        config['forced_generating_width'],
        config['forced_generating_height'],
        config['forced_denoising_strength_vary'],
        config['forced_denoising_strength_upscale'],
        config['mix_image_prompt_vary_upscale'],
        config['mix_image_prompt_inpaint'],
        config['debug_preprocessor_control_nets'],
        config['softness_of_control_net'],
        config['canny_low_threshold'],
        config['canny_high_threshold'],
        config['inpaint_engine'],
        config['refiner_swap_method'],
        config["freeu"],
        config["backbone_scale_f_1"],
        config["backbone_scale_f_2"],
        config["skip_scale_f_1"],
        config["skip_scale_f_2"],
        fn_index=22,
    )
    job = client.submit(
        config["prompt"],
        config["negative_prompt"],
        config["image_styles"],
        config["performance"],
        config["resolution"],
        config["image_number"],
        seed,
        config["sampling_sharpness"],
        config["cfg_scale"],
        config["sd_model_checkpoint"],
        config["sd_refiner_checkpoint"],
        config["sd_lora_1"],
        config["sd_lora_1_weight"],
        config["sd_lora_2"],
        config["sd_lora_2_weight"],
        config["sd_lora_3"],
        config["sd_lora_3_weight"],
        config["sd_lora_4"],
        config["sd_lora_4_weight"],
        config["sd_lora_5"],
        config["sd_lora_5_weight"],
        config['enhance_image'],
        config["tab"],
        config["variation_or_upscale"],
        image_dict['upscale_image'],
        config['outpaint_mode'],
        config['outpaint_image'],
        image_dict['image_prompt_1'],
        config['image_prompt_stop_at_1'],
        config['image_prompt_weight_1'],
        config['image_prompt_type_1'],
        image_dict['image_prompt_2'],
        config['image_prompt_stop_at_2'],
        config['image_prompt_weight_2'],
        config['image_prompt_type_2'],
        image_dict['image_prompt_3'],
        config['image_prompt_stop_at_3'],
        config['image_prompt_weight_3'],
        config['image_prompt_type_3'],
        image_dict['image_prompt_4'],
        config['image_prompt_stop_at_4'],
        config['image_prompt_weight_4'],
        config['image_prompt_type_4'],
        fn_index=23,
        result_callbacks=[lambda *result: save_result(task, *result)],
    )
    logger.info(f"Task {task.id} submitted")
    
    return job


@router.post("/fooocus/t2i")
def t2i(base: Base, authenticated: bool = Depends(authenticate)):
    task = Task.create(task_type="fooocus_t2i", config=base.dict())
    task.save()

    return model_to_dict(task)


@router.get("/fooocus/image")
def image(id: str, authenticated: bool = Depends(authenticate)):
    image_path = os.path.join(gradio_output_root_path, id)
    return FileResponse(image_path, media_type="image/png")
