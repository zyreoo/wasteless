import '../models/product.dart';
import 'api_service.dart';

/// One page of an offset-paginated API list.
typedef ApiPage<T> = ({List<T> items, int? next});

/// Accumulates offset pages on demand. State changes only after a request
/// succeeds, so a failed page never corrupts what is already shown.
class Pager<T> {
  Pager(this.fetch, this.idOf);
  final Future<ApiPage<T>> Function(int offset) fetch;
  final Object Function(T item) idOf;
  final _items = <Object, T>{};
  int? _next = 0;
  bool _loading = false;
  List<T> get items => List.unmodifiable(_items.values);
  bool get hasMore => _next != null;
  bool get loading => _loading;

  /// Refetches from the start, keeping as many items as were already loaded
  /// so a refresh does not throw away pages the user asked for.
  Future<List<T>> refresh() async {
    final target = _items.isEmpty ? 1 : _items.length;
    final fresh = <Object, T>{};
    int? next = 0;
    do {
      final page = await fetch(next!);
      for (final item in page.items) {
        fresh.putIfAbsent(idOf(item), () => item);
      }
      next = page.items.isEmpty ? null : page.next;
    } while (next != null && fresh.length < target);
    _items
      ..clear()
      ..addAll(fresh);
    _next = next;
    return items;
  }

  /// Loads the next page; returns false when there is nothing to load or a
  /// load is already running.
  Future<bool> more() async {
    final offset = _next;
    if (_loading || offset == null) return false;
    _loading = true;
    try {
      final page = await fetch(offset);
      for (final item in page.items) {
        _items.putIfAbsent(idOf(item), () => item);
      }
      _next = page.items.isEmpty ? null : page.next;
      return true;
    } finally {
      _loading = false;
    }
  }
}

class CommerceService {
  const CommerceService(this.api);
  final ApiService api;

  Future<ApiPage<Product>> productPage(int offset) async {
    final data = await api.request('GET', '/api/products?offset=$offset');
    return (
      items: (data['items'] as List).map((j) => Product.fromJson(j)).toList(),
      next: data['next_offset'] as int?,
    );
  }

  Pager<Product> productPager() => Pager(productPage, (p) => p.id);

  Future<ApiPage<Map<String, dynamic>>> orderPage(int offset) async {
    final data = await api.request('GET', '/api/orders?offset=$offset');
    return (
      items: (data['items'] as List)
          .map((j) => Map<String, dynamic>.from(j))
          .toList(),
      next: data['next_offset'] as int?,
    );
  }

  Pager<Map<String, dynamic>> orderPager() =>
      Pager(orderPage, (o) => o['id'] as Object);

  /// Full catalogue, for the merchant map which groups offers per shop.
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
  Future<Map<String, dynamic>> order(int id) async =>
      Map<String, dynamic>.from(await api.request('GET', '/api/orders/$id'));

  Future<Map<String, dynamic>> dashboard() async => Map<String, dynamic>.from(
    await api.request('GET', '/api/merchant/dashboard'),
  );
  Future<List<Map<String, dynamic>>> merchants() async =>
      ((await api.request('GET', '/api/merchants'))['items'] as List)
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
  Future<void> saveMerchant(Map<String, dynamic> data) async {
    await api.request('PUT', '/api/merchant/profile', body: data);
  }

  Future<void> seedProducts() async {
    await api.request('POST', '/api/merchant/seed');
  }

  Future<void> saveProduct(Map<String, dynamic> data, {int? id}) async {
    await api.request(
      id == null ? 'POST' : 'PUT',
      id == null ? '/api/merchant/products' : '/api/merchant/products/$id',
      body: data,
    );
  }

  Future<void> availability(int id, bool active) async {
    await api.request(
      'PATCH',
      '/api/merchant/products/$id',
      body: {'active': active},
    );
  }

  Future<void> transition(
    int id,
    String status, {
    String code = '',
    String reason = '',
  }) async {
    await api.request(
      'POST',
      '/api/orders/$id/status',
      body: {'status': status, 'code': code, 'reason': reason},
    );
  }
}
