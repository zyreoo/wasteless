import unittest

from starlette.middleware.cors import CORSMiddleware
from starlette.testclient import TestClient
from main import app


class MerchantCorsTests(unittest.TestCase):
    def test_configured_origin_can_preflight_merchant_put(self):
        options = next(m.kwargs for m in app.user_middleware if m.cls is CORSMiddleware)
        origin = 'https://wasteless-app.onrender.com'
        client = TestClient(CORSMiddleware(app, **{**options, 'allow_origins': [origin]}))
        headers = {'Origin': origin, 'Access-Control-Request-Method': 'PUT',
                   'Access-Control-Request-Headers': 'authorization,content-type'}
        result = client.options('/api/merchant/profile', headers=headers)
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.headers['access-control-allow-origin'], origin)
        self.assertIn('PUT', result.headers['access-control-allow-methods'])
        result = client.options('/api/merchant/profile', headers={**headers, 'Origin': 'https://untrusted.invalid'})
        self.assertEqual(result.status_code, 400)
        self.assertNotIn('access-control-allow-origin', result.headers)
