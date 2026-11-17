import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/prefs_keys.dart';
import '../../data/repositories/providers.dart';

class OnboardingSeenController extends Notifier<bool> {
  @override
  bool build() {
    return ref
            .watch(sharedPreferencesProvider)
            .getBool(PrefsKeys.onboardingSeen) ??
        false;
  }

  Future<void> complete() async {
    state = true;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefsKeys.onboardingSeen, true);
  }
}

final onboardingSeenProvider = NotifierProvider<OnboardingSeenController, bool>(
  OnboardingSeenController.new,
);
