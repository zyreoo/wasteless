import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'widgets/figma_layout.dart';
import 'pages/design_page.dart';
import 'pages/order_confirm_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FigmaDesign.load();
  runApp(
    const WastelessApp(
      initialRoute: String.fromEnvironment('INITIAL_ROUTE', defaultValue: '/'),
    ),
  );
}

class WastelessApp extends StatelessWidget {
  const WastelessApp({super.key, this.initialRoute = '/'});
  final String initialRoute;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Wasteless',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.theme,
    initialRoute: initialRoute,
    routes: {
      for (final entry in designRoutes.entries)
        entry.key: (_) => DesignPage(nodeId: entry.value),
      '/order-confirm': (_) => const OrderConfirmPage(),
      '/saved': (_) => const DesignPage(nodeId: '5:564', savedOnly: true),
      '/inventory': (_) => const DesignPage(nodeId: '5:564'),
      '/community': (_) => const DesignPage(nodeId: '10:3617'),
      '/order': (_) => const DesignPage(nodeId: '10:3827'),
      '/screens': (_) => const ScreenCatalogue(),
    },
  );
}

/// A separate review route keeps every Figma artboard directly accessible.
class ScreenCatalogue extends StatelessWidget {
  const ScreenCatalogue({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ecrane Wasteless')),
    body: ListView(
      children: [
        for (final entry in designRoutes.entries)
          ListTile(
            title: Text(entry.key),
            subtitle: Text('Figma ${entry.value}'),
            onTap: () => Navigator.pushNamed(context, entry.key),
          ),
        ListTile(
          title: const Text('/order-confirm'),
          subtitle: const Text('Figma 10:4007'),
          onTap: () => Navigator.pushNamed(context, '/order-confirm'),
        ),
      ],
    ),
  );
}
