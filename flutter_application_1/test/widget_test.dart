import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/preview_main.dart';
import 'package:flutter_application_1/pages/design_page.dart';
import 'package:flutter_application_1/widgets/figma_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await FigmaDesign.load();
    final font = FontLoader('PlusJakartaSans');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      font.addFont(rootBundle.load('fonts/PlusJakartaSans-$weight.ttf'));
    }
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final emojiFile = File('/System/Library/Fonts/Apple Color Emoji.ttc');
    if (emojiFile.existsSync()) {
      final emoji = FontLoader('Apple Color Emoji')
        ..addFont(
          Future.value(ByteData.sublistView(emojiFile.readAsBytesSync())),
        );
      await emoji.load();
    }
  });
  Future<void> pump(WidgetTester tester, String route) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('preview'),
        child: WastelessApp(key: UniqueKey(), initialRoute: route),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(Scaffold).first);
      for (final f in Directory(
        'assets/figma',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.png'))) {
        await precacheImage(AssetImage(f.path), ctx);
      }
    });
    await tester.pumpAndSettle();
    debugDisableShadows = true;
  }

  for (final route in [...designRoutes.keys, '/order-confirm', '/saved']) {
    testWidgets('Renders $route without layout or asset errors', (
      tester,
    ) async {
      await pump(tester, route);
      expect(tester.takeException(), isNull);
      if (Platform.environment['DESIGN_PREVIEWS'] == '1') {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('design/previews')..createSync(recursive: true);
          final name = route == '/'
              ? 'welcome'
              : route.substring(1).replaceAll('/', '-');
          File('${dir.path}/$name.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
  testWidgets('Onboarding proceeds through all three pages to registration', (
    tester,
  ) async {
    await pump(tester, '/');
    for (final id in ['5:30', '5:80', '10:4208', '10:4247']) {
      await tester.tap(find.byKey(ValueKey('action-$id')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('field-5:253')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Search filters real card widgets', (tester) async {
    await pump(tester, '/search');
    await tester.enterText(
      find.byKey(const ValueKey('field-5:592')),
      'Croissant',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node-5:614')), findsOneWidget);
    expect(find.byKey(const ValueKey('node-5:613')), findsNothing);
  });
  testWidgets('Cart quantity updates checkout totals', (tester) async {
    final state = PreviewState.instance;
    state.quantities.setAll(0, [1, 2, 1]);
    await pump(tester, '/cart');
    await tester.tap(find.byKey(const ValueKey('action-10:3852')));
    await tester.pumpAndSettle();
    expect(state.total, closeTo(14.1, .001));
    await tester.tap(find.byKey(const ValueKey('action-10:3924')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node-10:4000')), findsOneWidget);
    expect(tester.takeException(), isNull);
    state.quantities.setAll(0, [1, 2, 1]);
  });
  testWidgets('Settings toggles respond to taps', (tester) async {
    await pump(tester, '/settings');
    final before = PreviewState.instance.settings['5:1244'];
    await tester.tap(find.byKey(const ValueKey('action-5:1244')));
    await tester.pumpAndSettle();
    expect(PreviewState.instance.settings['5:1244'], !before!);
  });
  testWidgets('Phone widths keep layouts within the viewport', (tester) async {
    for (final width in [320.0, 430.0]) {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        WastelessApp(key: UniqueKey(), initialRoute: '/home'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
