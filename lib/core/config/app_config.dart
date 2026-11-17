import 'package:flutter/foundation.dart';

/// Compile-time configuration. Override with `--dart-define`.
enum AuthBackend { demo, firebase, supabase }

class AppConfig {
  const AppConfig._();

  static const String _authBackend = String.fromEnvironment(
    'AUTH_BACKEND',
    defaultValue: 'demo',
  );

  static AuthBackend get authBackend => switch (_authBackend) {
    'firebase' => AuthBackend.firebase,
    'supabase' => AuthBackend.supabase,
    _ => AuthBackend.demo,
  };

  static bool get useFirebase => authBackend == AuthBackend.firebase;

  static bool get useSupabaseAuth => authBackend == AuthBackend.supabase;

  /// Supabase is the production data backend. The URL is safe to commit; the
  /// anon key is a public client key and is supplied with `--dart-define`.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jipythusnrclazfjkkqp.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get supabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Set by `bootstrap()` after `Supabase.initialize` succeeds. Kept separate
  /// from [supabaseConfigured] so an invalid key can fall back to demo data
  /// instead of crashing the app at startup.
  static bool supabaseInitialized = false;

  static bool get supabaseEnabled => supabaseConfigured && supabaseInitialized;

  static const String appName = 'Nijaora';
  static const String tagline = 'Find your inner light.';
  static const String domain = 'nijaora.com';

  static const int searchPageSize = 20;
  static const int maxServedLgas = 15;
  static const int minPortfolioPhotos = 3;
  static const int maxPortfolioPhotos = 10;
  static const int maxListingImages = 5;

  /// Demo codes are generated per phone number and only revealed in debug
  /// builds. Release builds must use a real SMS/Supabase auth backend instead
  /// of the demo repository.
  static bool get showDemoOtp => authBackend == AuthBackend.demo && kDebugMode;

  static const String locationDatasetVersion = '2026.10.1';
}
