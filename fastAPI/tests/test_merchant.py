import unittest
from unittest.mock import Mock
from fastapi.testclient import TestClient
from auth import Identity, current_user
from main import app
from routes.commerce import repository
from services.commerce_service import cart_summary

class MerchantTests(unittest.TestCase):
    def setUp(self):
        self.repo=Mock()
        app.dependency_overrides[current_user]=lambda: Identity('11111111-1111-4111-8111-111111111111',None,'test')
        app.dependency_overrides[repository]=lambda:self.repo
        self.addCleanup(app.dependency_overrides.clear)
        self.client=TestClient(app)
    def test_cannot_forge_merchant_owner(self):
        data={'name':'Demo','address':'Example address','pickup_window':'18-19','latitude':44.4,'longitude':26.1,'owner_id':'other'}
        self.assertEqual(self.client.put('/api/merchant/profile',json=data).status_code,422)
        self.repo.rpc.assert_not_called()
    def test_seed_is_authenticated_rpc(self):
        self.repo.dashboard.return_value={'merchant':{'id':1},'products':[],'orders':[]}
        self.assertEqual(self.client.post('/api/merchant/seed').status_code,200)
        self.repo.rpc.assert_called_once_with('merchant',{'p_action':'seed','p_data':{}})
    def test_status_validated_and_code_forwarded(self):
        self.assertEqual(self.client.post('/api/orders/10/status',json={'status':'collected','code':'ABC12345'}).status_code,204)
        self.repo.rpc.assert_called_once_with('order_transition',{'p_order_id':10,'p_status':'collected','p_code':'ABC12345','p_reason':''})
        self.assertEqual(self.client.post('/api/orders/10/status',json={'status':'paid'}).status_code,422)
    def test_stock_boolean_and_negative_rejected(self):
        data={'name':'Demo','description':'Example','price':'19','original_price':'50','stock':1,'category':'Test','allergens':'Gluten','image_path':'assets/demo/rescue-bag.webp'}
        for stock in [True,-1,1.5]:
            self.assertEqual(self.client.post('/api/merchant/products',json={**data,'stock':stock}).status_code,422)
        self.repo.rpc.assert_not_called()
    def test_product_ownership_cannot_be_reassigned(self):
        data={'name':'Demo','description':'Example','price':'19','original_price':'50','stock':1,'category':'Test','allergens':'Gluten','image_path':'assets/demo/rescue-bag.webp','merchant_id':20}
        self.assertEqual(self.client.put('/api/merchant/products/1',json=data).status_code,422)
    def test_mixed_merchants_and_paused_offers_block_checkout(self):
        items=[{'quantity':1,'product':{'price':10,'stock':2,'merchant_id':m}} for m in [1,2]]
        self.assertFalse(cart_summary(items)['can_checkout'])
        self.assertFalse(cart_summary([{'quantity':1,'product':{'price':10,'stock':2,'active':False}}])['can_checkout'])
