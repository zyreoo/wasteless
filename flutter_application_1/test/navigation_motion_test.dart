import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/live_page.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  testWidgets('Tab body animates without fading navigation chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              PageRouteBuilder<void>(
                pageBuilder: (_, animation, secondary) => const LiveScaffold(
                  title: 'Test',
                  index: 1,
                  body: Text('Conținut'),
                ),
                transitionsBuilder: (_, animation, secondary, child) => child,
              ),
            ),
            child: const Text('Deschide'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Deschide'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.ancestor(
        of: find.byType(NavigationBar),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.text('Conținut'),
        matching: find.byType(FadeTransition),
      ),
      findsOneWidget,
    );
    expect(
      Theme.of(tester.element(find.text('Conținut')))
          .textTheme
          .bodyMedium!
          .fontFamily,
      'PlusJakartaSans',
    );
    await tester.pumpAndSettle();
  });
}
