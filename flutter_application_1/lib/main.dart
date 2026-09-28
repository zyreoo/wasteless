import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_controller.dart';
import 'config/app_config.dart';
import 'pages/design_page.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'widgets/figma_layout.dart';

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
  final auth = AuthController(Supabase.instance.client);
  final api = ApiService(baseUrl: config.apiUrl, accessToken: auth.accessToken);
  runApp(WastelessApp(auth: auth, api: api));
}

class WastelessApp extends StatelessWidget {
  const WastelessApp({super.key, required this.auth, required this.api});
  final AuthController auth;
  final ApiService api;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: auth,
    builder: (context, _) => MaterialApp(
      key: ValueKey(auth.user?.id),
      title: 'Wasteless',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: auth.signedIn
          ? AccountPage(auth: auth, api: api)
          : DesignPage(nodeId: designRoutes['/login']!, auth: auth),
      onGenerateRoute: (settings) {
        final route = settings.name;
        final public = route == '/register' || route == '/login';
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => public && !auth.signedIn
              ? DesignPage(nodeId: designRoutes[route]!, auth: auth)
              : auth.signedIn
              ? AccountPage(auth: auth, api: api)
              : DesignPage(nodeId: designRoutes['/login']!, auth: auth),
        );
      },
    ),
  );
}

/// Temporary authenticated landing while the existing commerce schema is unavailable.
/// Never substitute the seeded design preview for real account data.
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
          const Text('Catalogul și comenzile nu sunt disponibile momentan.'),
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
