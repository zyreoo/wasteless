import os
import unittest
from unittest.mock import MagicMock, patch

import httpx
from fastapi.testclient import TestClient
from main import app

A = '11111111-1111-4111-8111-111111111111'
B = '22222222-2222-4222-8222-222222222222'


class AuthTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self.env = patch.dict(os.environ, {
            'SUPABASE_URL': 'https://example.supabase.co',
            'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_test',
        })
        self.env.start()
        self.addCleanup(self.env.stop)
        self.http = patch('auth.httpx.Client')
        self.mock = self.http.start().return_value.__enter__.return_value
        self.addCleanup(self.http.stop)

    def respond(self, status=200, data=None):
        self.mock.get.return_value = httpx.Response(status, json=data or {'id': A, 'email': 'a@example.invalid'})

    def test_anonymous_is_rejected_without_external_request(self):
        for path in ['/api/me', '/api/cart/', '/api/favorite/', '/api/order/', '/api/users/']:
            with self.subTest(path=path):
                self.assertEqual(self.client.get(path).status_code, 401)
        self.mock.get.assert_not_called()

    def test_valid_session_uses_verified_identity_not_query_id(self):
        self.respond()
        r = self.client.get('/api/me', params={'user_id': B}, headers={'Authorization': 'Bearer test-token'})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()['id'], A)
        self.assertEqual(self.mock.get.call_args.kwargs['headers']['Authorization'], 'Bearer test-token')

    def test_rejected_session(self):
        for status in [401, 403]:
            self.respond(status)
            r = self.client.get('/api/me', headers={'Authorization': 'Bearer invalid'})
            self.assertEqual(r.status_code, 401)

    def test_unavailable_auth_is_not_success(self):
        self.mock.get.side_effect = httpx.ConnectError('private error')
        r = self.client.get('/api/me', headers={'Authorization': 'Bearer token'})
        self.assertEqual(r.status_code, 503)
        self.assertNotIn('private error', r.text)

    def test_malformed_identity_is_rejected(self):
        self.respond(data={'id': 'not-a-uuid'})
        self.assertEqual(self.client.get('/api/me', headers={'Authorization': 'Bearer token'}).status_code, 503)

    def test_auth_outage_not_reported_as_bad_password(self):
        self.respond(500)
        self.assertEqual(self.client.get('/api/me', headers={'Authorization': 'Bearer token'}).status_code, 503)

    def test_missing_config_fails_closed(self):
        with patch.dict(os.environ, {'SUPABASE_PUBLISHABLE_KEY': ''}):
            self.assertEqual(self.client.get('/api/me', headers={'Authorization': 'Bearer token'}).status_code, 503)
        self.mock.get.assert_not_called()

    def test_legacy_reads_cannot_expose_other_users(self):
        self.respond()
        for resource in ['cart', 'order', 'favorite', 'users', 'cart_items', 'order_items']:
            r = self.client.get(f'/api/{resource}/?user_id={B}', headers={'Authorization': 'Bearer token'})
            self.assertEqual(r.status_code, 503)
            self.assertNotIn(B, r.text)

    def test_health_does_not_require_secrets(self):
        self.assertEqual(self.client.get('/health').json(), {'status': 'ok'})
        self.mock.get.assert_not_called()


if __name__ == '__main__':
    unittest.main()
