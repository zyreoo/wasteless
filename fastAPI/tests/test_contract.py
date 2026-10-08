import os
import unittest
from unittest.mock import patch

from fastapi.routing import APIRoute
from starlette.middleware.cors import CORSMiddleware
from starlette.testclient import TestClient

os.environ.setdefault('RATE_LIMIT_ENABLED', 'true')
from main import app
from rate_limit import limiter

# Every call made by flutter_application_1/lib (ApiService.request callers).
FLUTTER_CONTRACT = {
    ('GET', '/api/me'),
    ('GET', '/api/products'),
    ('GET', '/api/products/{product_id}'),
    ('GET', '/api/favorites'),
    ('POST', '/api/favorites'),
    ('DELETE', '/api/favorites/{product_id}'),
    ('GET', '/api/cart'),
    ('POST', '/api/cart/items'),
    ('PATCH', '/api/cart/items/{item_id}'),
    ('DELETE', '/api/cart/items/{item_id}'),
    ('DELETE', '/api/cart'),
    ('GET', '/api/orders'),
    ('GET', '/api/orders/{order_id}'),
    ('POST', '/api/orders'),
    ('POST', '/api/orders/{order_id}/status'),
    ('GET', '/api/merchants'),
    ('GET', '/api/merchant/dashboard'),
    ('PUT', '/api/merchant/profile'),
    ('POST', '/api/merchant/seed'),
    ('POST', '/api/merchant/products'),
    ('PUT', '/api/merchant/products/{product_id}'),
    ('PATCH', '/api/merchant/products/{product_id}'),
    ('POST', '/api/merchant/photo'),
    ('DELETE', '/api/merchant/photo'),
}

# Visitors can browse offers and shops without an account.
PUBLIC_BROWSING = {
    ('GET', '/api/products'),
    ('GET', '/api/products/{product_id}'),
    ('GET', '/api/merchants'),
}


class FlutterContractTests(unittest.TestCase):
    def test_every_route_the_client_calls_is_served(self):
        served = {(method, route.path) for route in app.routes if isinstance(route, APIRoute)
                  for method in route.methods}
        self.assertEqual(FLUTTER_CONTRACT - served, set())

    def test_every_client_route_rejects_anonymous_calls(self):
        os.environ['RATE_LIMIT_ENABLED'] = 'false'
        try:
            client = TestClient(app)
            for method, path in sorted(FLUTTER_CONTRACT - PUBLIC_BROWSING):
                with self.subTest(f'{method} {path}'):
                    url = path.replace('{product_id}', '1').replace('{item_id}', '1').replace('{order_id}', '1')
                    # No Supabase is configured here, so a 401 proves the check
                    # happens before any data access.
                    response = client.request(method, url, json={})
                    self.assertEqual(response.status_code, 401)
                    self.assertEqual(response.headers.get('www-authenticate'), 'Bearer')
        finally:
            os.environ['RATE_LIMIT_ENABLED'] = 'true'

    @patch.dict(os.environ, {'SUPABASE_URL': '', 'SUPABASE_PUBLISHABLE_KEY': ''})
    def test_browsing_routes_serve_visitors(self):
        os.environ['RATE_LIMIT_ENABLED'] = 'false'
        try:
            client = TestClient(app)
            for method, path in sorted(PUBLIC_BROWSING):
                with self.subTest(f'{method} {path}'):
                    # No Supabase is configured here: the visitor got past
                    # authentication and reached the data layer.
                    response = client.request(method, path.replace('{product_id}', '1'))
                    self.assertEqual(response.status_code, 503)
        finally:
            os.environ['RATE_LIMIT_ENABLED'] = 'true'

    def test_health_stays_outside_the_rate_limit(self):
        self.assertIn('/health', {route.path for route in app.routes})

    def test_rate_limited_response_exposes_retry_after_cross_origin(self):
        origin = 'https://app.example.invalid'
        options = next(m.kwargs for m in app.user_middleware if m.cls is CORSMiddleware)
        client = TestClient(CORSMiddleware(app, **{**options, 'allow_origins': [origin]}))
        limiter.reset()
        os.environ['RATE_LIMIT_CHECKOUT_PER_MINUTE'] = '1'
        try:
            headers = {'Origin': origin, 'Idempotency-Key': '11111111-1111-4111-8111-111111111111'}
            client.post('/api/orders', headers=headers)
            limited = client.post('/api/orders', headers=headers)
        finally:
            os.environ.pop('RATE_LIMIT_CHECKOUT_PER_MINUTE')
            limiter.reset()
        self.assertEqual(limited.status_code, 429)
        self.assertEqual(limited.headers['access-control-allow-origin'], origin)
        self.assertIn('retry-after', limited.headers['access-control-expose-headers'].lower())
        self.assertGreaterEqual(int(limited.headers['retry-after']), 1)
