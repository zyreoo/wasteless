import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/product.dart';

typedef GeoPoint = ({double lat, double lng});

/// Centres used when the user has not shared their location.
const cityCenters = <String, GeoPoint>{
  'București': (lat: 44.4268, lng: 26.1025),
  'Cluj-Napoca': (lat: 46.7712, lng: 23.6236),
};

GeoPoint cityCenter(String city) =>
    cityCenters[city] ?? cityCenters['București']!;

/// Great-circle distance in kilometres (haversine).
double distanceKm(GeoPoint a, GeoPoint b) {
  const earth = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat), dLng = rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earth * math.asin(math.min(1, math.sqrt(h)));
}

/// "350 m", "1,2 km", "12 km".
String distanceLabel(double km) {
  if (km < 1) return '${((km * 1000) / 50).round() * 50} m';
  if (km < 10) return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  return '${km.round()} km';
}

GeoPoint? shopPoint(Map<String, dynamic>? merchant) {
  final lat = merchant?['latitude'], lng = merchant?['longitude'];
  return lat is num && lng is num
      ? (lat: lat.toDouble(), lng: lng.toDouble())
      : null;
}

abstract class LocationProvider {
  /// The device position, or null when unavailable or not permitted.
  Future<GeoPoint?> current();
}

class DeviceLocation implements LocationProvider {
  const DeviceLocation();
  @override
  Future<GeoPoint?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (lat: p.latitude, lng: p.longitude);
    } catch (_) {
      return null;
    }
  }
}

/// The shared position for this session only: kept in memory, never sent to
/// the server and never persisted (see the privacy policy).
class NearbyLocation extends ChangeNotifier {
  static final instance = NearbyLocation();
  GeoPoint? here;
  bool locating = false;

  Future<bool> locate(LocationProvider provider) async {
    if (locating) return here != null;
    locating = true;
    notifyListeners();
    try {
      here = await provider.current() ?? here;
      return here != null;
    } finally {
      locating = false;
      notifyListeners();
    }
  }

  @visibleForTesting
  void reset() {
    here = null;
    locating = false;
  }
}

/// Time filters for discovery.
enum PickupWhen { any, now, today, tomorrow }

/// The bag's pickup window: its dated window, or today's occurrence of the
/// shop's usual window ("19:00–20:00"), or null when unknown.
(DateTime, DateTime)? effectiveWindow(Product p, {DateTime? now}) {
  if (p.pickupStart != null && p.pickupEnd != null) {
    return (p.pickupStart!, p.pickupEnd!);
  }
  final text = p.merchant?['pickup_window'] as String?;
  final m = RegExp(r'(\d{1,2})[:.](\d{2})\s*[–-]\s*(\d{1,2})[:.](\d{2})')
      .firstMatch(text ?? '');
  if (m == null) return null;
  final day = DateUtils.dateOnly(now ?? DateTime.now());
  DateTime at(int h, int min) => DateTime(day.year, day.month, day.day, h, min);
  final start = at(int.parse(m.group(1)!), int.parse(m.group(2)!));
  final end = at(int.parse(m.group(3)!), int.parse(m.group(4)!));
  return end.isAfter(start) ? (start, end) : null;
}

bool matchesWhen(Product p, PickupWhen when, {DateTime? now}) {
  if (when == PickupWhen.any) return true;
  final clock = now ?? DateTime.now();
  final window = effectiveWindow(p, now: clock);
  if (window == null) return when == PickupWhen.today;
  final (start, end) = window;
  final today = DateUtils.dateOnly(clock);
  final day = DateUtils.dateOnly(start).difference(today).inDays;
  return switch (when) {
    // Open now, or opening within the next hour.
    PickupWhen.now =>
      end.isAfter(clock) && start.isBefore(clock.add(const Duration(hours: 1))),
    PickupWhen.today => day == 0 && end.isAfter(clock),
    PickupWhen.tomorrow => day == 1,
    PickupWhen.any => true,
  };
}
