import shutil
from fastapi import Body, FastAPI, Depends, UploadFile, Request, status
from typing import Annotated
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from playhouse.shortcuts import model_to_dict

from terminal import router as terminal_router
from sd_fooocus import router as fooocus_router
from db import Task
from share import *
from utils import get_gpu_info
from auth import authenticate

import logging
logging.basicConfig(level=logging.INFO)

temp_image_folder = os.path.join(os.getcwd(),"temp_image_folder")
os.makedirs(temp_image_folder, exist_ok=True)
app = FastAPI(docs_url=None, redoc_url=None)

# Allow CORS from all origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(terminal_router)
app.include_router(fooocus_router)

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    exc_str = f'{exc}'.replace('\n', ' ').replace('   ', ' ')
    logging.error(f"{request}: {exc_str}")
    content = {'status_code': 10422, 'message': exc_str, 'data': None}
    return JSONResponse(content=content, status_code=status.HTTP_422_UNPROCESSABLE_ENTITY)

@app.get('/status')
def get_status():
    return {'status': 'ok'}

@app.get('/info')
def get_info(authenticated: bool = Depends(authenticate)):
    gpu_info = get_gpu_info()
    return gpu_info

@app.get("/task/{task_id}")
def get_task(task_id: int, authenticated: bool = Depends(authenticate)):
    task = Task.get(Task.id==task_id)
    return model_to_dict(task)

@app.post("/task")
def get_tasks(task_ids: Annotated[list[int], Body()], authenticated: bool = Depends(authenticate)):
    tasks = Task.select().where(Task.id << task_ids)
    return [model_to_dict(task) for task in tasks]

@app.post("/task/image/{task_id}")
def post_task_image(task_id: int, file: UploadFile, authenticated: bool = Depends(authenticate)):
    folder = os.path.join(temp_image_folder, str(task_id))
    save_path = os.path.join(folder, file.filename)
    
    os.makedirs(folder, exist_ok=True)
    with open(save_path, "wb") as buf:
        shutil.copyfileobj(file.file, buf)
    file.file.close()
    return {"file_path": save_path}