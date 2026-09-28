import os
import logging
import time
from typing import Annotated

from dotenv import load_dotenv
from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from rate_limit import RateLimitMiddleware

load_dotenv()

from auth import Identity, current_user

app = FastAPI(title='Wasteless API')
logger = logging.getLogger('wasteless.http')


class RequestLogMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        started = time.monotonic()
        response = await call_next(request)
        elapsed = (time.monotonic() - started) * 1000
        logger.info('%s %s %s %.1fms', request.method, request.url.path,
                    response.status_code, elapsed)
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['Referrer-Policy'] = 'no-referrer'
        return response


app.add_middleware(RateLimitMiddleware)
app.add_middleware(RequestLogMiddleware)
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
