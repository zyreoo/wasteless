"""Small single-instance sliding-window limiter for the MVP API."""
import os
import threading
import time
from collections import defaultdict, deque
from typing import Annotated

from fastapi import Depends, HTTPException, Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from auth import Identity, current_user


class SlidingWindowLimiter:
    def __init__(self):
        self._events = defaultdict(deque)
        self._lock = threading.Lock()

    def reset(self):
        with self._lock:
            self._events.clear()

    def allow(self, key, limit, window=60, now=None):
        now = time.monotonic() if now is None else now
        cutoff = now - window
        with self._lock:
            events = self._events[key]
            while events and events[0] <= cutoff:
                events.popleft()
            if len(events) >= limit:
                return False, max(1, int(window - (now - events[0])) + 1)
            events.append(now)
            return True, 0


limiter = SlidingWindowLimiter()


def _bucket(request: Request):
    if request.url.path == '/health':
        return None
    method = request.method.upper()
    if request.url.path == '/api/orders' and method == 'POST':
        return 'checkout', int(os.getenv('RATE_LIMIT_CHECKOUT_PER_MINUTE', '6'))
    if method in {'POST', 'PATCH', 'PUT', 'DELETE'}:
        return 'write', int(os.getenv('RATE_LIMIT_WRITES_PER_MINUTE', '30'))
    return 'read', int(os.getenv('RATE_LIMIT_READS_PER_MINUTE', '120'))


def _client_key(request: Request):
    host = request.client.host if request.client else 'unknown'
    return f'ip:{host}'


class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        if os.getenv('RATE_LIMIT_ENABLED', 'true').lower() == 'false':
            return await call_next(request)
        bucket = _bucket(request)
        if bucket is None:
            return await call_next(request)
        name, limit = bucket
        allowed, retry_after = limiter.allow((_client_key(request), name), limit)
        if not allowed:
            return JSONResponse(
                {'detail': 'Prea multe cereri. Încearcă din nou în curând.'},
                status_code=429,
                headers={'Retry-After': str(retry_after)},
            )
        response = await call_next(request)
        response.headers['X-RateLimit-Limit'] = str(limit)
        return response


def user_rate_limit(
    request: Request,
    user: Annotated[Identity, Depends(current_user)],
):
    """Apply the same quota by verified user ID, across refreshed access tokens."""
    bucket = _bucket(request)
    if bucket is None:
        return
    name, limit = bucket
    allowed, retry_after = limiter.allow((f'user:{user.id}', name), limit)
    if not allowed:
        raise HTTPException(
            429,
            'Prea multe cereri. Încearcă din nou în curând.',
            headers={'Retry-After': str(retry_after)},
        )
