import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/config/app_config.dart';

void main() {
  test('Production configuration requires every public endpoint', () {
    const valid = AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_example',
      apiUrl: 'https://api.example.com',
      authRedirectUrl: 'https://app.example.com/#/reset-password',
    );
    expect(valid.isValid, true);
    expect(
      const AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        publishableKey: 'sb_publishable_example',
        apiUrl: 'https://api.example.com',
        authRedirectUrl: '',
      ).isValid,
      false,
    );
  });

  test('Secret-style keys are rejected from Flutter configuration', () {
    expect(
      const AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        publishableKey: 'sb_secret_never_ship_this',
        apiUrl: 'https://api.example.com',
        authRedirectUrl: 'https://app.example.com/#/reset-password',
      ).isValid,
      false,
    );
  });
}
