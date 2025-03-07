import time
import requests
from db import db, Task
from sd_fooocus import process_t2i as fooocus_process
from share import *
from gradio_client.utils import Status

import logging
logging.basicConfig(
    level=logging.INFO,
    format=log_format)


def wait_for_server_ready(url):
    # TODO: is timeout needed?
    while True:
        try:
            response = requests.get(url)
            if response.status_code == 200:
                return True
        except requests.exceptions.ConnectionError:
            pass
        time.sleep(1)
        


def process():
    jobs = {}
    logging.info("Start background process")
    # Assume only one process task, so restart all job on restart
    Task.update(status="Pending").where(Task.status == "Running").execute()
    
    def submit_task(task):
        if task.task_type == "fooocus_t2i":
            try:
                logging.info("Checking if server is ready")
                wait_for_server_ready("http://localhost:7015")
                logging.info("Server is ready")
                # save callback handler
                jobs[str(task.id)] = fooocus_process(task)
            except:
                #TODO retry
                logging.exception("Encountered error during fooocus inference")
                task.status = "Error"
                task.save()
                
    while True:
        task = None
        with db.transaction():
            task = (
                Task.select()
                .where(Task.status == "Pending")
                .first()
            )
            if task:
                logging.info(f"Processing task {task.id}")
                task.status = "Running"
                task.save()
        if task:
            submit_task(task)
            
        completed_task = []
        for task_id, job in jobs.items():
            status = job.status()
            if status.code == Status.FINISHED:
                if status.success:
                    logging.info(f"Task {task_id} finished, removing from monitor loop")
                    completed_task.append(task_id)
                else:
                    # TODO: maybe limit retry count
                    logging.warning(f"Task {task_id} failed, will try to resubmit")
                    submit_task(Task.get_by_id(int(task_id)))
                
        for task_id in completed_task:
            jobs.pop(task_id)
                
        time.sleep(1)

if __name__ == "__main__":
    process()

# TODO api for reading meta
# dirty workaround: read log in fooocus output folder, complete md5 with output image in gradio folder