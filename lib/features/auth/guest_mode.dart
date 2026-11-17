import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/prefs_keys.dart';
import '../../data/repositories/providers.dart';

/// Lets customers browse without an account. Sign-in is still required to
/// start a chat, review, or publish a business.
class GuestModeController extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(PrefsKeys.guestMode) ??
        false;
  }

  void enable() {
    state = true;
    ref.read(sharedPreferencesProvider).setBool(PrefsKeys.guestMode, true);
  }

  void disable() {
    state = false;
    ref.read(sharedPreferencesProvider).setBool(PrefsKeys.guestMode, false);
  }
}

final guestModeProvider =
    NotifierProvider<GuestModeController, bool>(GuestModeController.new);
