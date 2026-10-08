import os
import logging
import time
from typing import Annotated

import httpx
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Response
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
    allow_methods=['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
    allow_headers=['Authorization', 'Content-Type', 'Idempotency-Key'],
    # Browsers hide non-safelisted headers cross-origin; the client reads Retry-After on 429.
    expose_headers=['Retry-After'],
)


@app.get('/health')
def health(response: Response):
    url = os.getenv('SUPABASE_URL', '').rstrip('/')
    key = os.getenv('SUPABASE_PUBLISHABLE_KEY', '')
    if not url.startswith('https://') or not key.startswith('sb_publishable_'):
        response.status_code = 503
        return {'status': 'degraded'}
    try:
        with httpx.Client(timeout=3) as client:
            dependency = client.get(f'{url}/auth/v1/health', headers={'apikey': key})
        if dependency.status_code != 200:
            response.status_code = 503
            return {'status': 'degraded'}
    except httpx.RequestError:
        response.status_code = 503
        return {'status': 'degraded'}
    return {'status': 'ok'}


@app.get('/api/me')
def me(user: Annotated[Identity, Depends(current_user)]):
    return {'id': user.id, 'email': user.email}


from routes.commerce import public_router, router as commerce_router
app.include_router(public_router)
app.include_router(commerce_router)
