import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences extends ChangeNotifier {
  static final instance = AppPreferences();
  String city = 'București';
  bool reduceMotion = false;
  bool showDemo = true;
  final Set<String> savedMerchants = {};
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedCity = prefs.getString('discovery.city');
    city = ['București', 'Cluj-Napoca'].contains(storedCity)
        ? storedCity!
        : 'București';
    reduceMotion = prefs.getBool('discovery.reduceMotion') ?? false;
    showDemo = prefs.getBool('discovery.showDemo') ?? true;
    savedMerchants
      ..clear()
      ..addAll(prefs.getStringList('discovery.saved') ?? []);
    notifyListeners();
  }

  Future<void> update({
    String? city,
    bool? reduceMotion,
    bool? showDemo,
  }) async {
    this.city = city ?? this.city;
    this.reduceMotion = reduceMotion ?? this.reduceMotion;
    this.showDemo = showDemo ?? this.showDemo;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('discovery.city', this.city);
    await prefs.setBool('discovery.reduceMotion', this.reduceMotion);
    await prefs.setBool('discovery.showDemo', this.showDemo);
  }

  Future<void> toggleSaved(String id) async {
    if (!savedMerchants.remove(id)) savedMerchants.add(id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('discovery.saved', savedMerchants.toList());
  }
}
