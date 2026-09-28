"""Request-scoped PostgREST transport. The user's JWT keeps database RLS active."""
import logging
import os

import httpx
from fastapi import HTTPException

logger = logging.getLogger(__name__)
PRODUCT_COLUMNS = 'id,name,description,image_path,price,stock,category,location_id'


class CommerceRepository:
    def __init__(self, user, client=None):
        self.user = user
        self.client = client

    def request(self, method, path, *, params=None, body=None):
        url = os.getenv('SUPABASE_URL', '').rstrip('/')
        key = os.getenv('SUPABASE_PUBLISHABLE_KEY', '')
        if not url or not key:
            raise HTTPException(503, 'Serviciul nu este configurat.')
        headers = {'apikey': key, 'Authorization': f'Bearer {self.user.token}'}
        try:
            if self.client:
                response = self.client.request(method, f'{url}/rest/v1/{path}', params=params, json=body, headers=headers)
            else:
                with httpx.Client(timeout=15) as client:
                    response = client.request(method, f'{url}/rest/v1/{path}', params=params, json=body, headers=headers)
        except httpx.RequestError:
            logger.warning('Database transport unavailable')
            raise HTTPException(503, 'Datele nu sunt disponibile momentan.') from None
        if response.is_error:
            # Never return SQL errors, query details or row data to clients/logs.
            status = response.status_code if response.status_code in (401,403,404,409,422) else 503
            logger.warning('Database operation failed with status %s', response.status_code)
            raise HTTPException(status, 'Operația nu a reușit. Reîncarcă datele și încearcă din nou.')
        if not response.content:
            return None
        return response.json()

    def products(self, offset, limit):
        return self.request('GET', 'product', params={'select': PRODUCT_COLUMNS, 'active': 'eq.true', 'order': 'id', 'offset': offset, 'limit': limit})

    def product(self, id):
        rows = self.request('GET', 'product', params={'select': PRODUCT_COLUMNS, 'id': f'eq.{id}', 'active': 'eq.true'})
        if not rows:
            raise HTTPException(404, 'Produsul nu mai este disponibil.')
        return rows[0]

    def cart(self):
        carts = self.request('GET', 'cart', params={'select': 'id', 'user_id': f'eq.{self.user.id}'})
        if not carts:
            return []
        return self.request('GET', 'cart_items', params={'select': f'id,quantity,product_id,product({PRODUCT_COLUMNS})', 'cart_id': f'eq.{carts[0]["id"]}', 'order': 'id'})

    def favorites(self):
        return self.request('GET', 'favorite', params={'select': f'items_id,product({PRODUCT_COLUMNS})', 'user_id': f'eq.{self.user.id}', 'order': 'id'})

    def orders(self, id=None, offset=0, limit=50):
        params = {'select': 'id,created_at,total_price,subtotal,status,order_items(id,product_id,product_name,quantity,unit_price)',
                  'user_id': f'eq.{self.user.id}', 'order': 'created_at.desc,id.desc', 'limit': limit, 'offset': offset}
        if id is not None:
            params['id'] = f'eq.{id}'
        rows = self.request('GET', 'order', params=params)
        if id is not None:
            if not rows:
                raise HTTPException(404, 'Comanda nu a fost găsită.')
            return rows[0]
        return rows

    def rpc(self, name, params):
        return self.request('POST', f'rpc/wasteless_{name}', body=params)
