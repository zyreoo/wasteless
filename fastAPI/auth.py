"""Validate user sessions against Supabase Auth, never client-supplied IDs."""
import logging
import os
from dataclasses import dataclass
from typing import Annotated
from uuid import UUID

import httpx
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

logger = logging.getLogger(__name__)
bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class Identity:
    id: str
    email: str | None


def current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> Identity:
    if credentials is None:
        raise HTTPException(401, 'Autentificarea este necesară.', headers={'WWW-Authenticate': 'Bearer'})
    url = os.getenv('SUPABASE_URL', '').rstrip('/')
    key = os.getenv('SUPABASE_PUBLISHABLE_KEY', '')
    if not url or not key:
        raise HTTPException(503, 'Serviciul de autentificare nu este configurat.')
    try:
        with httpx.Client(timeout=10) as client:
            response = client.get(
                f'{url}/auth/v1/user',
                headers={'apikey': key, 'Authorization': f'Bearer {credentials.credentials}'},
            )
    except httpx.RequestError:
        logger.warning('Supabase Auth is unavailable')
        raise HTTPException(503, 'Autentificarea nu este disponibilă momentan.') from None
    if response.status_code in (401, 403):
        raise HTTPException(401, 'Sesiunea a expirat. Autentifică-te din nou.',
                            headers={'WWW-Authenticate': 'Bearer'})
    if response.status_code != 200:
        logger.warning('Supabase Auth returned status %s', response.status_code)
        raise HTTPException(503, 'Autentificarea nu este disponibilă momentan.')
    try:
        data = response.json()
        user_id = str(UUID(data['id']))
        email = data.get('email')
        if email is not None and not isinstance(email, str):
            raise ValueError('Invalid email shape')
    except (ValueError, TypeError, KeyError):
        raise HTTPException(503, 'Răspuns invalid de la serviciul de autentificare.') from None
    return Identity(id=user_id, email=email)


def require_verified_schema(user: Annotated[Identity, Depends(current_user)]) -> None:
    """Fail closed until ownership columns and database policies can be verified.

    Do not replace this guard with a configuration bypass. Replace legacy
    endpoints with owner-scoped operations once the real schema is available.
    """
    raise HTTPException(503, 'Datele aplicației nu sunt disponibile momentan.')
