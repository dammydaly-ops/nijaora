import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../data/repositories/location_repository.dart';
import '../data/repositories/providers.dart';
import '../data/sources/firebase/firebase_options.dart';
import '../data/sources/supabase/supabase_location_repository.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.useFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  LocationRepository? remoteLocations;
  if (AppConfig.supabaseConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
      AppConfig.supabaseInitialized = true;
      try {
        remoteLocations =
            await SupabaseLocationRepository.load(Supabase.instance.client);
      } catch (_) {
        // Migrations may not be applied yet. The bundled 774-LGA dataset is the
        // fallback until the remote reference tables are available.
        remoteLocations = null;
      }
    } catch (_) {
      // A bad key or network failure should not stop the demo fallback.
      AppConfig.supabaseInitialized = false;
    }
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (remoteLocations != null)
          locationRepositoryProvider.overrideWithValue(remoteLocations),
      ],
      child: const NijaoraApp(),
    ),
  );
}
