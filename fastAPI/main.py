import os
from typing import Annotated

from dotenv import load_dotenv
from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

load_dotenv()

from auth import Identity, current_user, require_verified_schema

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


# Preserve old URLs without exposing unscoped admin-backed reads. The real
# commerce routes replace these once the existing schema has been inspected.
for resource in (
    'cart', 'cart_items', 'favorite', 'favorites', 'order', 'orders', 'order_items',
    'settings', 'loyalty_points', 'users', 'product', 'products', 'offers',
    'offer_items', 'merchants', 'locations', 'location_type', 'order_status', 'order_type',
):
    app.add_api_route(
        f'/api/{resource}/', require_verified_schema, methods=['GET'],
        include_in_schema=False,
    )
