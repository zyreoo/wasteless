import os
import unittest
from unittest.mock import Mock, patch

from fastapi.testclient import TestClient

from auth import Identity, current_user
from main import app
from rate_limit import SlidingWindowLimiter, limiter
from routes.commerce import repository


class LimiterTests(unittest.TestCase):
    def test_sliding_window_returns_retry_signal(self):
        value = SlidingWindowLimiter()
        self.assertEqual(value.allow('a', 2, now=10), (True, 0))
        self.assertEqual(value.allow('a', 2, now=11), (True, 0))
        allowed, retry = value.allow('a', 2, now=12)
        self.assertFalse(allowed)
        self.assertGreater(retry, 0)
        self.assertEqual(value.allow('a', 2, now=71), (True, 0))

    def test_checkout_is_limited_and_returns_429(self):
        limiter.reset()
        repo = Mock()
        repo.rpc.return_value = 1
        repo.orders.return_value = {'id': 1}
        app.dependency_overrides[current_user] = lambda: Identity(
            '11111111-1111-4111-8111-111111111111', None, 'token'
        )
        app.dependency_overrides[repository] = lambda: repo
        self.addCleanup(app.dependency_overrides.clear)
        with patch.dict(os.environ, {'RATE_LIMIT_CHECKOUT_PER_MINUTE': '2'}):
            client = TestClient(app)
            headers = {
                'Authorization': 'Bearer unique-rate-token',
                'Idempotency-Key': '33333333-3333-4333-8333-333333333333',
            }
            self.assertEqual(client.post('/api/orders', headers=headers).status_code, 201)
            self.assertEqual(client.post('/api/orders', headers=headers).status_code, 201)
            response = client.post('/api/orders', headers=headers)
            self.assertEqual(response.status_code, 429)
            self.assertIn('Retry-After', response.headers)


if __name__ == '__main__':
    unittest.main()
