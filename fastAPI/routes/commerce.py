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
