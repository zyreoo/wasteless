from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Header, Query, Response
from pydantic import BaseModel, ConfigDict, Field

from auth import Identity, current_user
from repositories.commerce_repository import CommerceRepository
from services.commerce_service import cart_summary
from rate_limit import user_rate_limit

router = APIRouter(prefix='/api', dependencies=[Depends(user_rate_limit)])


def repository(user: Annotated[Identity, Depends(current_user)]):
    return CommerceRepository(user)


Repo = Annotated[CommerceRepository, Depends(repository)]


class ProductInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    product_id: int = Field(gt=0)


class AddItem(ProductInput):
    quantity: int = Field(ge=1, le=99, strict=True)


class QuantityInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    quantity: int = Field(ge=0, le=99, strict=True)


@router.get('/products')
def products(repo: Repo, offset: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=100)):
    rows = repo.products(offset, limit + 1)
    return {'items': rows[:limit], 'next_offset': offset + limit if len(rows) > limit else None}


@router.get('/products/{product_id}')
def product(product_id: int, repo: Repo):
    return repo.product(product_id)


@router.get('/cart')
def cart(repo: Repo):
    return cart_summary(repo.cart())


@router.post('/cart/items', status_code=201)
def add_item(data: AddItem, repo: Repo):
    repo.rpc('cart', {'p_action': 'add', 'p_product_id': data.product_id, 'p_quantity': data.quantity})
    return cart_summary(repo.cart())


@router.patch('/cart/items/{item_id}')
def change_item(item_id: int, data: QuantityInput, repo: Repo):
    repo.rpc('cart', {'p_action': 'set', 'p_item_id': item_id, 'p_quantity': data.quantity})
    return cart_summary(repo.cart())


@router.delete('/cart/items/{item_id}', status_code=204)
def remove_item(item_id: int, repo: Repo):
    repo.rpc('cart', {'p_action': 'remove', 'p_item_id': item_id})
    return Response(status_code=204)


@router.delete('/cart', status_code=204)
def clear_cart(repo: Repo):
    repo.rpc('cart', {'p_action': 'clear'})
    return Response(status_code=204)


@router.get('/favorites')
def favorites(repo: Repo):
    return {'items': [r['product'] for r in repo.favorites() if r['product'] is not None]}


@router.post('/favorites', status_code=204)
def save_favorite(data: ProductInput, repo: Repo):
    repo.rpc('favorite', {'p_product_id': data.product_id, 'p_saved': True})
    return Response(status_code=204)


@router.delete('/favorites/{product_id}', status_code=204)
def unsave_favorite(product_id: int, repo: Repo):
    repo.rpc('favorite', {'p_product_id': product_id, 'p_saved': False})
    return Response(status_code=204)


@router.get('/orders')
def orders(repo: Repo, offset: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=100)):
    rows = repo.orders(offset=offset, limit=limit+1)
    return {'items': rows[:limit], 'next_offset': offset+limit if len(rows)>limit else None}


@router.get('/orders/{order_id}')
def order(order_id: int, repo: Repo):
    return repo.orders(id=order_id)


@router.post('/orders', status_code=201)
def checkout(repo: Repo, idempotency_key: Annotated[UUID, Header()]):
    oid = repo.rpc('checkout', {'p_key': str(idempotency_key)})
    return repo.orders(id=oid)

# Merchant ownership is enforced again inside the database functions.
from decimal import Decimal
from typing import Literal


class MerchantProfileInput(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    name: str = Field(min_length=2, max_length=100)
    address: str = Field(min_length=5, max_length=300)
    pickup_window: str = Field(min_length=3, max_length=100)
    latitude: float = Field(ge=-90, le=90, allow_inf_nan=False)
    longitude: float = Field(ge=-180, le=180, allow_inf_nan=False)


class MerchantProductInput(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    name: str = Field(min_length=2, max_length=150)
    description: str = Field(max_length=2000)
    price: Decimal = Field(gt=0, le=10000, decimal_places=2)
    original_price: Decimal = Field(gt=0, le=10000, decimal_places=2)
    stock: int = Field(ge=0, le=10000, strict=True)
    category: str = Field(min_length=2, max_length=80)
    allergens: str = Field(min_length=2, max_length=500)
    image_path: Literal['assets/demo/apples.webp', 'assets/demo/pears.webp', 'assets/demo/rescue-bag.webp']


class AvailabilityInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    active: bool = Field(strict=True)


class TransitionInput(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    status: Literal['accepted', 'ready', 'collected', 'cancelled']
    code: str = Field(default='', max_length=20)
    reason: str = Field(default='', max_length=500)


@router.get('/merchants')
def merchant_directory(repo: Repo):
    return {'items': repo.merchants()}


@router.get('/merchant/dashboard')
def merchant_dashboard(repo: Repo):
    return repo.dashboard()


@router.put('/merchant/profile')
def merchant_profile(data: MerchantProfileInput, repo: Repo):
    repo.rpc('merchant', {'p_action': 'profile', 'p_data': data.model_dump(mode='json')})
    return repo.dashboard()


@router.post('/merchant/seed')
def merchant_seed(repo: Repo):
    repo.rpc('merchant', {'p_action': 'seed', 'p_data': {}})
    return repo.dashboard()


@router.post('/merchant/products', status_code=201)
def merchant_create_product(data: MerchantProductInput, repo: Repo):
    pid = repo.rpc('merchant', {'p_action': 'product', 'p_data': data.model_dump(mode='json')})
    return {'id': pid}


@router.put('/merchant/products/{product_id}')
def merchant_update_product(product_id: int, data: MerchantProductInput, repo: Repo):
    repo.rpc('merchant', {'p_action': 'product', 'p_data': {**data.model_dump(mode='json'), 'id': product_id}})
    return {'id': product_id}


@router.patch('/merchant/products/{product_id}')
def merchant_availability(product_id: int, data: AvailabilityInput, repo: Repo):
    repo.rpc('merchant', {'p_action': 'availability', 'p_data': {'id': product_id, 'active': data.active}})
    return {'id': product_id}


@router.post('/orders/{order_id}/status', status_code=204)
def transition_order(order_id: int, data: TransitionInput, repo: Repo):
    repo.rpc('order_transition', {'p_order_id': order_id, 'p_status': data.status, 'p_code': data.code, 'p_reason': data.reason})
    return Response(status_code=204)
