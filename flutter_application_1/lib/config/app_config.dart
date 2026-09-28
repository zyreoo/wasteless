class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.publishableKey,
    required this.apiUrl,
  });
  final String supabaseUrl, publishableKey, apiUrl;
  factory AppConfig.environment() => const AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    apiUrl: String.fromEnvironment('API_BASE_URL'),
  );
  bool get isValid =>
      [supabaseUrl, apiUrl].every((value) {
        final uri = Uri.tryParse(value);
        return uri != null &&
            ['http', 'https'].contains(uri.scheme) &&
            uri.host.isNotEmpty;
      }) &&
      publishableKey.startsWith('sb_publishable_');
}
