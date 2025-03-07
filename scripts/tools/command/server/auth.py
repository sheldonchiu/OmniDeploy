from share import *
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBasic, HTTPBasicCredentials


security = HTTPBasic()
# define a function to authenticate users
def authenticate(credentials: HTTPBasicCredentials = Depends(security)):
    """Authenticate users with basic auth"""
    if username is None or password is None:
        return True

    if credentials.username != username or credentials.password != password:
        raise HTTPException(status_code=401, detail="Invalid username or password")
    return True