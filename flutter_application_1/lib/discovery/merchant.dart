import 'package:latlong2/latlong.dart';

/// Illustrative merchants only. These never enter the production checkout.
class DemoMerchant {
  const DemoMerchant(
    this.id,
    this.name,
    this.category,
    this.area,
    this.price,
    this.originalPrice,
    this.pickup,
    this.image,
    this.offset,
    this.description,
  );
  final String id, name, category, area, pickup, image, description;
  final int price, originalPrice;
  final LatLng offset;
  LatLng location(String city) {
    final center = city == 'Cluj-Napoca'
        ? const LatLng(46.7712, 23.6236)
        : const LatLng(44.435, 26.102);
    return LatLng(
      center.latitude + offset.latitude,
      center.longitude + offset.longitude,
    );
  }

  int get discount => ((1 - price / originalPrice) * 100).round();
}

const demoMerchants = [
  DemoMerchant(
    'atelier',
    'Atelierul de pâine',
    'Brutării',
    'Centru',
    19,
    55,
    '18:00–19:00',
    'assets/demo/rescue-bag.webp',
    LatLng(.004, -.009),
    'O selecție surpriză de pâine și produse de brutărie. Conținutul diferă de la o zi la alta. Exemplu demonstrativ, fără rezervare.',
  ),
  DemoMerchant(
    'gradina',
    'Grădina de lângă tine',
    'Fructe & legume',
    'Piața centrală',
    15,
    45,
    '17:00–18:30',
    'assets/demo/apples.webp',
    LatLng(-.006, .012),
    'Fructe și legume cu personalitate, numai bune pentru următoarea masă. Exemplu demonstrativ, fără rezervare.',
  ),
  DemoMerchant(
    'verde',
    'Bistro Verde',
    'Restaurante',
    'Cartierul vechi',
    25,
    70,
    '20:00–21:00',
    'assets/demo/rescue-bag.webp',
    LatLng(.013, .005),
    'Descoperă o selecție surpriză din meniul zilei. Exemplu demonstrativ; ingredientele și alergenii ar fi confirmați de comerciant.',
  ),
  DemoMerchant(
    'livada',
    'Mica livadă',
    'Fructe & legume',
    'Zona parcului',
    12,
    35,
    '16:30–18:00',
    'assets/demo/pears.webp',
    LatLng(-.011, -.014),
    'Un coș de fructe de sezon, pentru gustări și deserturi. Exemplu demonstrativ, fără rezervare.',
  ),
];
