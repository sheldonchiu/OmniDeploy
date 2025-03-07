from pydantic import BaseModel
from fastapi import APIRouter
from fastapi import HTTPException, Depends
from subprocess import PIPE, run, CalledProcessError

from auth import authenticate

class Command(BaseModel):
    command: str
    
router = APIRouter()

# define a route that executes a command and returns the output
@router.post("/execute")
def execute_command(command: Command, authenticated: bool = Depends(authenticate)):
    """Execute a command and return the output"""
    try:
        result = run(command.command, shell=True, stdout=PIPE, stderr=PIPE, universal_newlines=True)
        output = result.stdout
        error = result.stderr
    except CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Error executing command: {e}")
    return {"code": result.returncode, "output": output, "error": error}

@router.post("/run")
def start_process(command: Command, authenticated: bool = Depends(authenticate)):
    """Start a background process"""
    try:
        run(command.command, shell=True, check=False)
    except CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Error starting process: {e}")
    return {"code": "0", "output": "Process started in the background."}