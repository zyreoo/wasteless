import '../models/product.dart';
import 'api_service.dart';

class CommerceService {
  const CommerceService(this.api);
  final ApiService api;
  Future<List<Product>> products({bool saved = false}) async {
    final items = <Product>[];
    int? offset = 0;
    do {
      final data = await api.request(
        'GET',
        saved ? '/api/favorites' : '/api/products?offset=$offset',
      );
      items.addAll((data['items'] as List).map((j) => Product.fromJson(j)));
      offset = data['next_offset'] as int?;
    } while (offset != null);
    return items;
  }

  Future<Product> product(int id) async =>
      Product.fromJson(await api.request('GET', '/api/products/$id'));
  Future<void> favorite(int id, bool saved) async {
    await api.request(
      saved ? 'POST' : 'DELETE',
      saved ? '/api/favorites' : '/api/favorites/$id',
      body: saved ? {'product_id': id} : null,
    );
  }

  Future<Map<String, dynamic>> cart() async =>
      Map<String, dynamic>.from(await api.request('GET', '/api/cart'));
  Future<void> add(int id, int quantity) async {
    await api.request(
      'POST',
      '/api/cart/items',
      body: {'product_id': id, 'quantity': quantity},
    );
  }

  Future<void> quantity(int id, int quantity) async {
    await api.request(
      'PATCH',
      '/api/cart/items/$id',
      body: {'quantity': quantity},
    );
  }

  Future<void> remove(int id) async {
    await api.request('DELETE', '/api/cart/items/$id');
  }

  Future<void> clear() async {
    await api.request('DELETE', '/api/cart');
  }

  Future<Map<String, dynamic>> checkout(String key) async =>
      Map<String, dynamic>.from(
        await api.request('POST', '/api/orders', idempotencyKey: key),
      );
  Future<List<Map<String, dynamic>>> orders() async {
    final items = <Map<String, dynamic>>[];
    int? offset = 0;
    do {
      final data = await api.request('GET', '/api/orders?offset=$offset');
      items.addAll(
        (data['items'] as List).map((j) => Map<String, dynamic>.from(j)),
      );
      offset = data['next_offset'] as int?;
    } while (offset != null);
    return items;
  }

  Future<Map<String, dynamic>> order(int id) async =>
      Map<String, dynamic>.from(await api.request('GET', '/api/orders/$id'));
}
