"""Request-scoped PostgREST transport. The user's JWT keeps database RLS active."""
import logging
import os
import uuid
from datetime import datetime, timezone

import httpx
from fastapi import HTTPException

logger = logging.getLogger(__name__)
ORDER_COLUMNS = 'id,created_at,updated_at,total_price,subtotal,status,merchant_id,merchant_name,pickup_address,pickup_window,pickup_start,pickup_end,pickup_code,is_demo,cancellation_reason,order_items(id,product_id,product_name,quantity,unit_price)'
PRODUCT_COLUMNS = 'id,name,description,image_path,price,stock,category,location_id,active,merchant_id,original_price,allergens,is_demo,pickup_start,pickup_end,merchants(id,name,address,pickup_window,latitude,longitude,image_url)'


class CommerceRepository:
    def __init__(self, user, client=None):
        self.user = user
        self.client = client

    def request(self, method, path, *, params=None, body=None):
        url = os.getenv('SUPABASE_URL', '').rstrip('/')
        key = os.getenv('SUPABASE_PUBLISHABLE_KEY', '')
        if not url or not key:
            raise HTTPException(503, 'Serviciul nu este configurat.')
        # Without a user the request runs as the anonymous role, which can only
        # call the public catalogue functions.
        headers = {'apikey': key}
        if self.user is not None:
            headers['Authorization'] = f'Bearer {self.user.token}'
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
            safe_messages = {
                'One merchant per order': 'Alege produse de la un singur comerciant pentru fiecare comandă.',
                'Insufficient stock': 'Stoc insuficient. Actualizează cantitatea.',
                'Product unavailable': 'Un produs nu mai este disponibil. Actualizează coșul.',
                'Invalid pickup code': 'Codul de ridicare nu este corect.',
                'Invalid transition': 'Starea comenzii s-a schimbat. Reîncarcă datele.',
                'Order cannot be cancelled': 'Comanda nu mai poate fi anulată.',
                'Cancellation reason required': 'Completează motivul anulării.',
                'Invalid product': 'Verifică prețurile, stocul și alergenii.',
                'Invalid pickup window': 'Verifică ziua și intervalul de ridicare: în viitor, în următoarele 7 zile, maximum 12 ore.',
                'One pickup window per order': 'O comandă poate conține doar pachete cu același interval de ridicare.',
                'Invalid image': 'Imaginea nu este validă.',
                'Pickup not ended': 'Comanda poate fi închisă după terminarea intervalului de ridicare.',
            }
            try:
                detail = safe_messages.get(response.json().get('message'), 'Operația nu a reușit. Reîncarcă datele și încearcă din nou.')
            except (ValueError, AttributeError):
                detail = 'Operația nu a reușit. Încearcă din nou.'
            raise HTTPException(status, detail)
        if not response.content:
            return None
        return response.json()

    def products(self, offset, limit):
        if self.user is None:
            return self.request('POST', 'rpc/wasteless_catalog', body={'p_offset': offset, 'p_limit': limit})
        # RLS already hides ended pickups from customers; this also hides them
        # from a merchant browsing the catalogue with their own bags in it.
        now = datetime.now(timezone.utc).isoformat()
        return self.request('GET', 'product', params={'select': PRODUCT_COLUMNS, 'active': 'eq.true', 'or': f'(pickup_end.is.null,pickup_end.gt.{now})', 'order': 'id', 'offset': offset, 'limit': limit})

    def product(self, id):
        if self.user is None:
            rows = self.request('POST', 'rpc/wasteless_catalog', body={'p_id': id})
        else:
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
        params = {'select': ORDER_COLUMNS,
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

    def merchants(self):
        if self.user is None:
            return self.request('POST', 'rpc/wasteless_shops', body={})
        return self.request('GET', 'merchants', params={'select': 'id,name,address,pickup_window,latitude,longitude,is_demo,image_url', 'owner_id':'not.is.null', 'status':'eq.approved', 'order':'id', 'limit':100})

    def dashboard(self):
        rows = self.request('GET', 'merchants', params={'select':'id,name,address,pickup_window,latitude,longitude,is_demo,demo_seeded,image_url,status','owner_id':f'eq.{self.user.id}'})
        if not rows:
            return {'merchant':None,'products':[],'orders':[]}
        merchant = rows[0]
        products = self.request('GET','product',params={'select':PRODUCT_COLUMNS,'merchant_id':f'eq.{merchant["id"]}','order':'id','limit':500})
        # Pickup code belongs to the customer; the merchant enters it at collection.
        orders = self.request('GET','order',params={'select':ORDER_COLUMNS.replace('pickup_code,',''),'merchant_id':f'eq.{merchant["id"]}','order':'created_at.desc,id.desc','limit':200})
        return {'merchant':merchant,'products':products,'orders':orders}

    def upload_shop_photo(self, content, content_type, extension):
        """Store a shop photo in the caller's own folder, with the caller's token,
        so the storage policies (owner folder only) apply."""
        url = os.getenv('SUPABASE_URL', '').rstrip('/')
        key = os.getenv('SUPABASE_PUBLISHABLE_KEY', '')
        if not url or not key:
            raise HTTPException(503, 'Serviciul nu este configurat.')
        path = f'{self.user.id}/{uuid.uuid4().hex}.{extension}'
        headers = {'apikey': key, 'Authorization': f'Bearer {self.user.token}',
                   'Content-Type': content_type, 'x-upsert': 'false'}
        target = f'{url}/storage/v1/object/shop-images/{path}'
        try:
            if self.client:
                response = self.client.request('POST', target, content=content, headers=headers)
            else:
                with httpx.Client(timeout=30) as client:
                    response = client.request('POST', target, content=content, headers=headers)
        except httpx.RequestError:
            logger.warning('Storage transport unavailable')
            raise HTTPException(503, 'Imaginea nu a putut fi încărcată acum.') from None
        if response.is_error:
            logger.warning('Storage upload failed with status %s', response.status_code)
            raise HTTPException(503, 'Imaginea nu a putut fi încărcată acum.')
        return f'{url}/storage/v1/object/public/shop-images/{path}'
