import os
from typing import Annotated

from dotenv import load_dotenv
from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

load_dotenv()

from auth import Identity, current_user

app = FastAPI(title='Wasteless API')
origins = [value.strip() for value in os.getenv('CORS_ORIGINS', '').split(',') if value.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_methods=['GET', 'POST', 'PATCH', 'DELETE'],
    allow_headers=['Authorization', 'Content-Type', 'Idempotency-Key'],
)


@app.get('/health')
def health():
    return {'status': 'ok'}


@app.get('/api/me')
def me(user: Annotated[Identity, Depends(current_user)]):
    return {'id': user.id, 'email': user.email}


from routes.commerce import router as commerce_router
app.include_router(commerce_router)
