class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.description,
    this.image,
    this.category,
  });
  final int id, stock;
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
  );
}

String money(Object? value) =>
    '${num.parse('$value').toStringAsFixed(2).replaceAll('.', ',')} lei';
