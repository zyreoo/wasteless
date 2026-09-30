class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.description,
    this.image,
    this.category,
    this.merchantId,
    this.merchant,
    this.allergens,
    this.isDemo = false,
    this.originalPrice,
  });
  final int id, stock;
  final int? merchantId;
  final Map<String, dynamic>? merchant;
  final String? allergens;
  final bool isDemo;
  final num? originalPrice;
  final String name;
  final String? description, image, category;
  final num price;
  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'] as int,
    name: j['name'] as String,
    price: num.parse('${j['price']}'),
    stock: j['stock'] as int,
    description: j['description'] as String?,
    image: j['image_path'] as String?,
    category: j['category'] as String?,
    merchantId: j['merchant_id'] as int?,
    merchant: j['merchants'] == null
        ? null
        : Map<String, dynamic>.from(j['merchants']),
    allergens: j['allergens'] as String?,
    isDemo: j['is_demo'] == true,
    originalPrice: j['original_price'] == null
        ? null
        : num.parse('${j['original_price']}'),
  );
}

String money(Object? value) =>
    '${num.parse('$value').toStringAsFixed(2).replaceAll('.', ',')} lei';
