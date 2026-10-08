import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/discovery/information_pages.dart';
import 'package:flutter_application_1/discovery/preferences.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.instance.load();
  });
  testWidgets('Settings persist reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.theme, home: const SettingsPage()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Animații reduse'));
    await tester.pumpAndSettle();
    final stored = await SharedPreferences.getInstance();
    expect(stored.getBool('discovery.reduceMotion'), isTrue);
  });
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('Information screens fit width $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final page in [
        const SettingsPage(),
        const HelpPage(),
        const AboutPage(),
        const BusinessPage(),
      ]) {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: page));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
