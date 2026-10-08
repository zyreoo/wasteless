import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences extends ChangeNotifier {
  static final instance = AppPreferences();
  String city = 'București';
  bool reduceMotion = false;
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedCity = prefs.getString('discovery.city');
    city = ['București', 'Cluj-Napoca'].contains(storedCity)
        ? storedCity!
        : 'București';
    reduceMotion = prefs.getBool('discovery.reduceMotion') ?? false;
    notifyListeners();
  }

  Future<void> update({String? city, bool? reduceMotion}) async {
    this.city = city ?? this.city;
    this.reduceMotion = reduceMotion ?? this.reduceMotion;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('discovery.city', this.city);
    await prefs.setBool('discovery.reduceMotion', this.reduceMotion);
  }
}
