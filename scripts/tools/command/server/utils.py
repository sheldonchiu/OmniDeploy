import requests
import base64
import pynvml

def get_gpu_info():
    pynvml.nvmlInit()
    device_count = pynvml.nvmlDeviceGetCount()

    gpu_info = []
    for i in range(device_count):
        handle = pynvml.nvmlDeviceGetHandleByIndex(i)

        gpu_name = pynvml.nvmlDeviceGetName(handle)
        gpu_memory_info = pynvml.nvmlDeviceGetMemoryInfo(handle)
        gpu_memory_total = gpu_memory_info.total / 1024**2  # Convert to MB
        gpu_memory_used = gpu_memory_info.used / 1024**2  # Convert to MB

        gpu_info.append({
            "index": i,
            "name": gpu_name,
            "memory_total": gpu_memory_total,
            "memory_used": gpu_memory_used
        })

    pynvml.nvmlShutdown()
    return gpu_info

def download_image_as_base64(url):
    response = requests.get(url, stream=True)
    image_data = response.content
    base64_str = base64.b64encode(image_data).decode('utf-8')
    return base64_str