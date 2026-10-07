import unittest
from unittest.mock import Mock

from fastapi.testclient import TestClient

from auth import Identity, current_user
from main import app
from repositories.commerce_repository import CommerceRepository
from routes.commerce import repository

USER = '11111111-1111-4111-8111-111111111111'
BAG = {'name': 'Pachet surpriză de patiserie', 'description': 'Valoare estimată 45 lei', 'price': '15',
       'original_price': '45', 'stock': 5, 'category': 'Patiserie', 'allergens': 'Poate conține: gluten',
       'image_path': 'assets/demo/rescue-bag.webp'}
JPEG = b'\xff\xd8\xff\xe0' + b'\x00' * 64
PNG = b'\x89PNG\r\n\x1a\n' + b'\x00' * 64
WEBP = b'RIFF\x00\x00\x00\x00WEBPVP8 ' + b'\x00' * 64


class PickupWindowTests(unittest.TestCase):
    def setUp(self):
        self.repo = Mock()
        self.repo.rpc.return_value = 7  # new product id
        app.dependency_overrides[current_user] = lambda: Identity(USER, None, 'token')
        app.dependency_overrides[repository] = lambda: self.repo
        self.addCleanup(app.dependency_overrides.clear)
        self.client = TestClient(app)

    def test_dated_window_is_forwarded_as_iso_timestamps(self):
        window = {'pickup_start': '2026-10-09T19:00:00+03:00', 'pickup_end': '2026-10-09T20:00:00+03:00'}
        self.assertEqual(self.client.post('/api/merchant/products', json={**BAG, **window}).status_code, 201)
        sent = self.repo.rpc.call_args.args[1]['p_data']
        self.assertEqual((sent['pickup_start'], sent['pickup_end']), ('2026-10-09T19:00:00+03:00', '2026-10-09T20:00:00+03:00'))

    def test_bag_without_window_is_still_valid(self):
        self.assertEqual(self.client.post('/api/merchant/products', json=BAG).status_code, 201)
        sent = self.repo.rpc.call_args.args[1]['p_data']
        self.assertIsNone(sent['pickup_start'])

    def test_incomplete_reversed_or_naive_windows_are_rejected(self):
        for window in [{'pickup_start': '2026-10-09T19:00:00+03:00'},
                       {'pickup_start': '2026-10-09T20:00:00+03:00', 'pickup_end': '2026-10-09T19:00:00+03:00'},
                       {'pickup_start': '2026-10-09T19:00:00', 'pickup_end': '2026-10-09T20:00:00'}]:
            with self.subTest(window=window):
                self.assertEqual(self.client.post('/api/merchant/products', json={**BAG, **window}).status_code, 422)
        self.repo.rpc.assert_not_called()


class ShopPhotoTests(unittest.TestCase):
    def setUp(self):
        self.repo = Mock()
        self.repo.upload_shop_photo.return_value = f'https://x.supabase.co/storage/v1/object/public/shop-images/{USER}/a.jpg'
        self.repo.dashboard.return_value = {'merchant': {'id': 1}, 'products': [], 'orders': []}
        app.dependency_overrides[current_user] = lambda: Identity(USER, None, 'token')
        app.dependency_overrides[repository] = lambda: self.repo
        self.addCleanup(app.dependency_overrides.clear)
        self.client = TestClient(app)

    def post(self, content, content_type):
        return self.client.post('/api/merchant/photo', content=content, headers={'Content-Type': content_type})

    def test_each_supported_format_is_stored_and_linked(self):
        for content, kind, ext in [(JPEG, 'image/jpeg', 'jpg'), (PNG, 'image/png', 'png'), (WEBP, 'image/webp', 'webp')]:
            with self.subTest(kind=kind):
                self.repo.reset_mock()
                self.assertEqual(self.post(content, kind).status_code, 200)
                self.repo.upload_shop_photo.assert_called_once_with(content, kind, ext)
                self.repo.rpc.assert_called_once_with('merchant', {'p_action': 'photo', 'p_data': {'image_url': self.repo.upload_shop_photo.return_value}})

    def test_wrong_type_disguised_file_and_oversize_are_rejected(self):
        self.assertEqual(self.post(JPEG, 'image/gif').status_code, 415)
        self.assertEqual(self.post(JPEG, 'image/png').status_code, 415)
        self.assertEqual(self.post(b'<svg onload=alert(1)>', 'image/jpeg').status_code, 415)
        self.assertEqual(self.post(b'', 'image/jpeg').status_code, 415)
        self.assertEqual(self.post(JPEG + b'\x00' * (2 * 1024 * 1024), 'image/jpeg').status_code, 413)
        self.repo.upload_shop_photo.assert_not_called()
        self.repo.rpc.assert_not_called()

    def test_photo_can_be_removed(self):
        self.assertEqual(self.client.delete('/api/merchant/photo').status_code, 200)
        self.repo.rpc.assert_called_once_with('merchant', {'p_action': 'photo', 'p_data': {'image_url': None}})


class RepositoryTests(unittest.TestCase):
    def test_upload_uses_the_callers_token_and_own_folder(self):
        client = Mock()
        client.request.return_value = Mock(is_error=False)
        repo = CommerceRepository(Identity(USER, None, 'user-token'), client=client)
        import os
        os.environ.setdefault('SUPABASE_URL', 'https://x.supabase.co')
        os.environ.setdefault('SUPABASE_PUBLISHABLE_KEY', 'sb_publishable_test')
        url = repo.upload_shop_photo(JPEG, 'image/jpeg', 'jpg')
        method, target = client.request.call_args.args
        headers = client.request.call_args.kwargs['headers']
        self.assertEqual(method, 'POST')
        self.assertIn(f'/storage/v1/object/shop-images/{USER}/', target)
        self.assertEqual(headers['Authorization'], 'Bearer user-token')
        self.assertTrue(url.endswith('.jpg') and f'/object/public/shop-images/{USER}/' in url)

    def test_catalogue_hides_ended_pickups(self):
        repo = CommerceRepository(Identity(USER, None, 't'))
        repo.request = Mock(return_value=[])
        repo.products(0, 10)
        params = repo.request.call_args.kwargs['params']
        self.assertTrue(params['or'].startswith('(pickup_end.is.null,pickup_end.gt.'))
