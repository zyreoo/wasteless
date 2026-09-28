import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/auth/auth_controller.dart';
import 'package:flutter_application_1/pages/password_recovery_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late AuthController auth;
  var calls = 0;
  setUp(() {
    calls = 0;
    client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((_) async {
        calls++;
        return http.Response(jsonEncode({}), 200);
      }),
    );
    auth = AuthController(
      client,
      recoveryRedirectUrl: 'https://app.example/reset-password',
    );
  });
  tearDown(() async {
    auth.dispose();
    await client.dispose();
  });

  testWidgets('Recovery validates email locally', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ForgotPasswordPage(auth: auth)));
    await tester.tap(find.byKey(const ValueKey('recovery-submit')));
    await tester.pump();
    expect(find.text('Introdu o adresă de email validă.'), findsOneWidget);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
