import unittest
from unittest.mock import Mock, patch
from fastapi import HTTPException
from fastapi.testclient import TestClient
import httpx
from auth import Identity, current_user
from main import app
from routes.commerce import browsing_repository, repository
from repositories.commerce_repository import CommerceRepository
from services.commerce_service import cart_summary

A='11111111-1111-4111-8111-111111111111'
B='22222222-2222-4222-8222-222222222222'


class CommerceTests(unittest.TestCase):
    def setUp(self):
        self.repo=Mock()
        app.dependency_overrides[current_user]=lambda: Identity(A,'a@example.invalid','user-token')
        app.dependency_overrides[repository]=lambda:self.repo
        app.dependency_overrides[browsing_repository]=lambda:self.repo
        self.client=TestClient(app)
        self.addCleanup(app.dependency_overrides.clear)

    def test_selected_product_is_passed_to_transaction(self):
        self.repo.cart.return_value=[]
        r=self.client.post('/api/cart/items',json={'product_id':22,'quantity':2})
        self.assertEqual(r.status_code,201)
        self.repo.rpc.assert_called_once_with('cart',{'p_action':'add','p_product_id':22,'p_quantity':2})

    def test_forged_owner_or_price_is_rejected(self):
        for extra in [{'user_id':B},{'price':0},{'total':0}]:
            r=self.client.post('/api/cart/items',json={'product_id':1,'quantity':1,**extra})
            self.assertEqual(r.status_code,422)
        self.repo.rpc.assert_not_called()

    def test_invalid_quantities(self):
        for qty in [-1,0,100,True,1.5,'1']:
            self.assertEqual(self.client.post('/api/cart/items',json={'product_id':1,'quantity':qty}).status_code,422)

    def test_zero_quantity_is_sent_for_removal(self):
        self.repo.cart.return_value=[]
        self.assertEqual(self.client.patch('/api/cart/items/9',json={'quantity':0}).status_code,200)
        self.repo.rpc.assert_called_with('cart',{'p_action':'set','p_item_id':9,'p_quantity':0})

    def test_missing_or_other_users_item_returns_404(self):
        self.repo.rpc.side_effect=HTTPException(404,'Not found')
        self.assertEqual(self.client.delete('/api/cart/items/44').status_code,404)

    def test_clear_cart(self):
        self.assertEqual(self.client.delete('/api/cart').status_code,204)
        self.repo.rpc.assert_called_with('cart',{'p_action':'clear'})

    def test_favorites_return_distinct_actual_products(self):
        self.repo.favorites.return_value=[{'product':{'id':1}},{'product':{'id':3}}]
        self.assertEqual(self.client.get('/api/favorites').json(),{'items':[{'id':1},{'id':3}]})

    def test_favorites_mutations(self):
        self.assertEqual(self.client.post('/api/favorites',json={'product_id':3}).status_code,204)
        self.repo.rpc.assert_called_with('favorite',{'p_product_id':3,'p_saved':True})
        self.assertEqual(self.client.delete('/api/favorites/3').status_code,204)
        self.repo.rpc.assert_called_with('favorite',{'p_product_id':3,'p_saved':False})

    def test_checkout_requires_valid_idempotency_key(self):
        self.assertEqual(self.client.post('/api/orders').status_code,422)
        self.assertEqual(self.client.post('/api/orders',headers={'Idempotency-Key':'bad'}).status_code,422)
        self.repo.rpc.assert_not_called()

    def test_checkout_uses_database_order_not_client_total(self):
        self.repo.rpc.return_value=7
        self.repo.orders.return_value={'id':7,'total_price':'9.60'}
        key='33333333-3333-4333-8333-333333333333'
        r=self.client.post('/api/orders',json={'total':0,'user_id':B},headers={'Idempotency-Key':key})
        self.assertEqual(r.status_code,201)
        self.assertEqual(r.json()['total_price'],'9.60')
        self.repo.rpc.assert_called_once_with('checkout',{'p_key':key})

    def test_product_detail_uses_requested_id(self):
        self.repo.product.return_value={'id':42}
        self.assertEqual(self.client.get('/api/products/42').json(),{'id':42})
        self.repo.product.assert_called_once_with(42)

    def test_decimal_cart_totals(self):
        result=cart_summary([{'quantity':3,'product':{'price':0.1,'stock':5}}, {'quantity':1,'product':{'price':'2.80','stock':1}}])
        self.assertEqual(result['total'],'3.10')
        self.assertTrue(result['can_checkout'])
        self.assertFalse(cart_summary([])['can_checkout'])
        self.assertFalse(cart_summary([{'quantity':1,'product':None}])['can_checkout'])


class RepositoryTests(unittest.TestCase):
    def setUp(self):
        self.http=Mock()
        self.repo=CommerceRepository(Identity(A,None,'verified-token'),self.http)
        self.env=patch.dict('os.environ',{'SUPABASE_URL':'https://example.supabase.co','SUPABASE_PUBLISHABLE_KEY':'sb_publishable_test'})
        self.env.start();self.addCleanup(self.env.stop)

    def response(self,data,status=200):
        self.http.request.return_value=httpx.Response(status,json=data)

    def test_orders_always_filter_verified_owner(self):
        self.response([])
        self.repo.orders()
        kwargs=self.http.request.call_args.kwargs
        self.assertEqual(kwargs['params']['user_id'],f'eq.{A}')
        self.assertEqual(kwargs['headers']['Authorization'],'Bearer verified-token')

    def test_favorites_owner_filter(self):
        self.response([]);self.repo.favorites()
        self.assertEqual(self.http.request.call_args.kwargs['params']['user_id'],f'eq.{A}')

    def test_cart_owner_filter(self):
        self.response([]);self.assertEqual(self.repo.cart(),[])
        self.assertEqual(self.http.request.call_args.kwargs['params']['user_id'],f'eq.{A}')

    def test_visitors_browse_through_the_public_catalogue(self):
        visitor=CommerceRepository(None,self.http)
        self.response([{'id':7}])
        self.assertEqual(visitor.products(0,51),[{'id':7}])
        call=self.http.request.call_args
        self.assertEqual(call.args[:2],('POST','https://example.supabase.co/rest/v1/rpc/wasteless_catalog'))
        self.assertEqual(call.kwargs['json'],{'p_offset':0,'p_limit':51})
        self.assertNotIn('Authorization',call.kwargs['headers'])
        self.assertEqual(visitor.product(7),{'id':7})
        self.assertEqual(self.http.request.call_args.kwargs['json'],{'p_id':7})
        self.response([])
        with self.assertRaises(HTTPException) as e:visitor.product(8)
        self.assertEqual(e.exception.status_code,404)
        visitor.merchants()
        self.assertTrue(self.http.request.call_args.args[1].endswith('/rpc/wasteless_shops'))

    def test_other_users_order_is_not_found(self):
        self.response([])
        with self.assertRaises(HTTPException) as e:self.repo.orders(id=44)
        self.assertEqual(e.exception.status_code,404)

    def test_database_403_preserved_without_leaking_error(self):
        self.response({'message':'private query'},403)
        with self.assertRaises(HTTPException) as e:self.repo.products(0,10)
        self.assertEqual(e.exception.status_code,403)
        self.assertNotIn('private query',e.exception.detail)

    def test_tokens_do_not_appear_in_identity_repr(self):
        self.assertNotIn('verified-token',repr(self.repo.user))
