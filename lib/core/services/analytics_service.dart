import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin analytics facade. Swap the body for Firebase Analytics later without
/// touching feature code.
class AnalyticsService {
  const AnalyticsService();

  void track(String event, [Map<String, Object?> params = const {}]) {
    if (kDebugMode) {
      debugPrint('[analytics] $event $params');
    }
    // TODO(analytics): forward to Firebase Analytics once configured.
  }
}

final analyticsProvider = Provider<AnalyticsService>((ref) {
  return const AnalyticsService();
});
