import 'merchant/merchant_dashboard.dart';
import 'merchant/merchant_directory.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'discovery/discovery_page.dart';
import 'discovery/information_pages.dart';
import 'discovery/merchant.dart';
import 'discovery/preferences.dart';
import 'auth/auth_controller.dart';
import 'config/app_config.dart';
import 'pages/design_page.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'widgets/figma_layout.dart';
import 'widgets/live_page.dart';
import 'services/commerce_service.dart';
import 'pages/catalog_page.dart';
import 'pages/live_product_page.dart';
import 'pages/live_cart_page.dart';
import 'pages/live_checkout_page.dart';
import 'pages/live_orders_page.dart';
import 'pages/password_recovery_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPreferences.instance.load();
  final config = AppConfig.environment();
  if (!config.isValid) {
    runApp(
      MaterialApp(
        title: 'Wasteless',
        theme: AppTheme.theme,
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aplicația nu este configurată. Verifică setările de conectare.',
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.publishableKey,
  );
  await FigmaDesign.load();
  final auth = AuthController(
    Supabase.instance.client,
    recoveryRedirectUrl: config.authRedirectUrl,
  );
  final api = ApiService(
    baseUrl: config.apiUrl,
    accessToken: auth.accessToken,
    onSessionRejected: auth.sessionRejected,
  );
  runApp(WastelessApp(auth: auth, api: api));
}

class WastelessApp extends StatelessWidget {
  const WastelessApp({super.key, required this.auth, required this.api});
  final AuthController auth;
  final ApiService api;

  PageRoute<void> _route(RouteSettings settings, Widget child) =>
      PageRouteBuilder<void>(
        settings: settings,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (_, animation, secondaryAnimation) => child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context) ||
              LiveScaffold.routes.contains(settings.name) ||
              settings.name == '/explore' ||
              settings.name == '/map') {
            return child;
          }
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .012),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );

  Widget authenticatedRoute(RouteSettings settings) {
    final service = CommerceService(api);
    final id = settings.arguments;
    return switch (settings.name) {
      '/search' => MerchantDirectory(service: service),
      '/map' => MerchantDirectory(service: service, mapFirst: true),
      '/explore' => MerchantDirectory(service: service),
      '/settings' => const SettingsPage(),
      '/help' => const HelpPage(),
      '/about' => const AboutPage(),
      '/business' => MerchantDashboard(service: service),
      '/saved' => CatalogPage(service: service, savedOnly: true),
      '/cart' => LiveCartPage(service: service),
      '/checkout' => LiveCheckoutPage(service: service),
      '/history' => LiveOrdersPage(service: service),
      '/profile' => AccountPage(auth: auth, api: api),
      '/product' when id is int => LiveProductPage(service: service, id: id),
      '/order-detail' when id is int => LiveOrderDetailPage(
        service: service,
        id: id,
      ),
      '/order-confirm' when id is int => LiveOrderDetailPage(
        service: service,
        id: id,
        confirmation: true,
      ),
      _ => CatalogPage(service: service),
    };
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([auth, AppPreferences.instance]),
    builder: (context, _) => MaterialApp(
      // Recovery mode swaps the whole stack, like an account change does.
      key: ValueKey((auth.user?.id, auth.recovering)),
      title: 'Wasteless',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations:
              MediaQuery.disableAnimationsOf(context) ||
              AppPreferences.instance.reduceMotion,
        ),
        child: BrowseSession(key: ValueKey(auth.user?.id), child: child!),
      ),
      home: auth.recovering
          ? ResetPasswordPage(auth: auth)
          : auth.signedIn
          ? CatalogPage(service: CommerceService(api))
          : DesignPage(nodeId: designRoutes['/login']!, auth: auth),
      onGenerateRoute: (settings) {
        final route = settings.name;
        final public =
            route == '/register' ||
            route == '/login' ||
            route == '/forgot-password';
        final informational = switch (route) {
          '/settings' => const SettingsPage(),
          '/search' =>
            auth.signedIn
                ? MerchantDirectory(service: CommerceService(api))
                : const DiscoveryPage(),
          '/help' => const HelpPage(),
          '/about' => const AboutPage(),
          '/business' =>
            auth.signedIn
                ? MerchantDashboard(service: CommerceService(api))
                : const BusinessPage(),
          '/explore' =>
            auth.signedIn
                ? MerchantDirectory(service: CommerceService(api))
                : const DiscoveryPage(),
          '/map' =>
            auth.signedIn
                ? MerchantDirectory(
                    service: CommerceService(api),
                    mapFirst: true,
                  )
                : const DiscoveryPage(mapFirst: true),
          // Illustrative merchants belong to the signed-out preview only.
          '/merchant'
              when !auth.signedIn &&
                  settings.arguments is String &&
                  demoMerchants.any((m) => m.id == settings.arguments) =>
            MerchantPage(
              merchant: demoMerchants.firstWhere(
                (m) => m.id == settings.arguments,
              ),
            ),
          _ => null,
        };
        if (informational != null && !auth.recovering) {
          return _route(settings, informational);
        }
        final child = route == '/forgot-password' && !auth.signedIn
            ? ForgotPasswordPage(auth: auth)
            : auth.recovering
            ? ResetPasswordPage(auth: auth)
            : public && !auth.signedIn
            ? DesignPage(nodeId: designRoutes[route]!, auth: auth)
            : auth.signedIn
            ? authenticatedRoute(settings)
            : DesignPage(nodeId: designRoutes['/login']!, auth: auth);
        return _route(settings, child);
      },
    ),
  );
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.auth, required this.api});
  final AuthController auth;
  final ApiService api;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late Future<dynamic> identity = widget.api.request('GET', '/api/me');
  bool signingOut = false;
  Future<void> logout() async {
    setState(() => signingOut = true);
    try {
      await widget.auth.logout();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AuthController.message(error))));
      }
    } finally {
      if (mounted) setState(() => signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Wasteless')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          FutureBuilder<dynamic>(
            future: identity,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Column(
                  children: [
                    Text(AuthController.message(snapshot.error!)),
                    TextButton(
                      onPressed: () => setState(
                        () => identity = widget.api.request('GET', '/api/me'),
                      ),
                      child: const Text('Încearcă din nou'),
                    ),
                  ],
                );
              }
              return Text(
                snapshot.data['email'] as String? ?? 'Contul tău',
                style: Theme.of(context).textTheme.titleLarge,
              );
            },
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/history'),
            child: const Text('Comenzile mele'),
          ),
          const Divider(height: 32),
          for (final item in <(IconData, String, String)>[
            (Icons.tune, 'Setări & preferințe', '/settings'),
            (Icons.map_outlined, 'Descoperă pe hartă', '/map'),
            (Icons.storefront_outlined, 'Pentru comercianți', '/business'),
            (Icons.help_outline, 'Ajutor', '/help'),
            (Icons.eco_outlined, 'Despre noi', '/about'),
          ])
            ListTile(
              leading: Icon(item.$1),
              title: Text(item.$2),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, item.$3),
            ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: signingOut ? null : logout,
            child: Text(signingOut ? 'Se deconectează…' : 'Deconectare'),
          ),
        ],
      ),
    ),
  );
}
