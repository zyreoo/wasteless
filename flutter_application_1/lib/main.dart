import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_controller.dart';
import 'config/app_config.dart';
import 'pages/design_page.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'widgets/figma_layout.dart';
import 'services/commerce_service.dart';
import 'pages/catalog_page.dart';
import 'pages/live_product_page.dart';
import 'pages/live_cart_page.dart';
import 'pages/live_checkout_page.dart';
import 'pages/live_orders_page.dart';
import 'pages/password_recovery_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    startInRecovery: kIsWeb && Uri.base.toString().contains('reset-password'),
  );
  final api = ApiService(baseUrl: config.apiUrl, accessToken: auth.accessToken);
  runApp(WastelessApp(auth: auth, api: api));
}

class WastelessApp extends StatelessWidget {
  const WastelessApp({super.key, required this.auth, required this.api});
  final AuthController auth;
  final ApiService api;

  Widget authenticatedRoute(RouteSettings settings) {
    final service = CommerceService(api);
    final id = settings.arguments;
    return switch (settings.name) {
      '/search' => CatalogPage(service: service, search: true),
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
    listenable: auth,
    builder: (context, _) => MaterialApp(
      key: ValueKey(auth.user?.id),
      title: 'Wasteless',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
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
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => route == '/forgot-password' && !auth.signedIn
              ? ForgotPasswordPage(auth: auth)
              : auth.recovering
              ? ResetPasswordPage(auth: auth)
              : public && !auth.signedIn
              ? DesignPage(nodeId: designRoutes[route]!, auth: auth)
              : auth.signedIn
              ? authenticatedRoute(settings)
              : DesignPage(nodeId: designRoutes['/login']!, auth: auth),
        );
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
