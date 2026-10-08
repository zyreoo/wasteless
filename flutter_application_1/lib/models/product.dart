import 'package:flutter/material.dart';

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
    this.originalPrice,
    this.pickupStart,
    this.pickupEnd,
  });
  final int id, stock;
  final int? merchantId;
  final Map<String, dynamic>? merchant;
  final String? allergens;
  final num? originalPrice;
  final String name;
  final String? description, image, category;
  final num price;

  /// Dated pickup window of this bag, when the shop set one.
  final DateTime? pickupStart, pickupEnd;

  /// "Azi, 19:00–20:00" for dated bags, otherwise the shop's usual window.
  String? get pickupLabel =>
      pickupWindowLabel(pickupStart, pickupEnd) ??
      merchant?['pickup_window'] as String?;
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
    originalPrice: j['original_price'] == null
        ? null
        : num.parse('${j['original_price']}'),
    pickupStart: parseTime(j['pickup_start']),
    pickupEnd: parseTime(j['pickup_end']),
  );
}

String money(Object? value) =>
    '${num.parse('$value').toStringAsFixed(2).replaceAll('.', ',')} lei';

DateTime? parseTime(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// Formats a dated pickup window relative to [now]: "Azi, 19:00–20:00",
/// "Mâine, 19:00–20:00" or "12.10, 19:00–20:00". Null when undated.
String? pickupWindowLabel(DateTime? start, DateTime? end, {DateTime? now}) {
  if (start == null || end == null) return null;
  String two(int v) => v.toString().padLeft(2, '0');
  String time(DateTime t) => '${two(t.hour)}:${two(t.minute)}';
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final days = DateUtils.dateOnly(start).difference(today).inDays;
  final day = switch (days) {
    0 => 'Azi',
    1 => 'Mâine',
    _ => '${two(start.day)}.${two(start.month)}',
  };
  return '$day, ${time(start)}–${time(end)}';
}
