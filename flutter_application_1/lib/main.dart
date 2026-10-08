import 'merchant/merchant_dashboard.dart';
import 'merchant/merchant_directory.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'discovery/information_pages.dart';
import 'discovery/legal_pages.dart';
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
      // Visitors start on the real offers; an account is needed to reserve.
      // An expired session or a failed email link is explained on sign-in.
      home: auth.recovering
          ? ResetPasswordPage(auth: auth)
          : !auth.signedIn && auth.notice != null
          ? DesignPage(nodeId: designRoutes['/login']!, auth: auth)
          : CatalogPage(service: CommerceService(api, guest: !auth.signedIn)),
      onGenerateRoute: (settings) {
        final route = settings.name;
        final public =
            route == '/register' ||
            route == '/login' ||
            route == '/forgot-password';
        final visitor = CommerceService(api, guest: true);
        final informational = switch (route) {
          '/settings' => const SettingsPage(),
          '/home' when !auth.signedIn => CatalogPage(service: visitor),
          '/product' when !auth.signedIn && settings.arguments is int =>
            LiveProductPage(service: visitor, id: settings.arguments as int),
          '/search' ||
          '/explore' when !auth.signedIn => MerchantDirectory(service: visitor),
          '/map' when !auth.signedIn => MerchantDirectory(
            service: visitor,
            mapFirst: true,
          ),
          '/help' => const HelpPage(),
          '/about' => const AboutPage(),
          '/terms' => const TermsPage(),
          '/privacy' => const PrivacyPage(),
          '/business' =>
            auth.signedIn
                ? MerchantDashboard(service: CommerceService(api))
                : const BusinessPage(),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (widget.auth.user?.userMetadata?['display_name'] as String?)
        ?.trim();
    return LiveScaffold(
      title: 'Contul meu',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.xl),
          children: [
            PageWidth(
              maxWidth: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FutureBuilder<dynamic>(
                    future: identity,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Row(
                          children: [
                            SkeletonBox(
                              width: 56,
                              height: 56,
                              radius: Radii.pill,
                            ),
                            SizedBox(width: Space.l),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonBox(width: 160, height: 18),
                                SizedBox(height: Space.s),
                                SkeletonBox(width: 200, height: 12),
                              ],
                            ),
                          ],
                        );
                      }
                      if (snapshot.hasError) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AuthController.message(snapshot.error!)),
                            TextButton(
                              onPressed: () => setState(
                                () => identity = widget.api.request(
                                  'GET',
                                  '/api/me',
                                ),
                              ),
                              child: const Text('Încearcă din nou'),
                            ),
                          ],
                        );
                      }
                      final email = snapshot.data['email'] as String? ?? '';
                      final title = name?.isNotEmpty == true
                          ? name!
                          : email.isNotEmpty
                          ? email
                          : 'Contul tău';
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.brandSoft,
                            child: Text(
                              title[0].toUpperCase(),
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: AppColors.brand,
                              ),
                            ),
                          ),
                          const SizedBox(width: Space.l),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge,
                                ),
                                if (title != email && email.isNotEmpty)
                                  Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: Space.xxl),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final (i, item) in <(IconData, String, String)>[
                          (
                            Icons.receipt_long_outlined,
                            'Comenzile mele',
                            '/history',
                          ),
                          (Icons.favorite_border, 'Favorite', '/saved'),
                          (Icons.tune, 'Setări și preferințe', '/settings'),
                          (
                            Icons.storefront_outlined,
                            'Pentru comercianți',
                            '/business',
                          ),
                          (Icons.help_outline, 'Ajutor', '/help'),
                          (Icons.eco_outlined, 'Despre Wasteless', '/about'),
                          (
                            Icons.description_outlined,
                            'Termeni de utilizare',
                            '/terms',
                          ),
                          (
                            Icons.privacy_tip_outlined,
                            'Confidențialitate',
                            '/privacy',
                          ),
                        ].indexed) ...[
                          if (i > 0) const Divider(indent: 56),
                          ListTile(
                            leading: Icon(item.$1, size: 22),
                            title: Text(item.$2),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                            ),
                            onTap: () => Navigator.pushNamed(context, item.$3),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: signingOut ? null : logout,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      icon: const Icon(Icons.logout, size: 18),
                      label: Text(
                        signingOut ? 'Se deconectează…' : 'Deconectare',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
