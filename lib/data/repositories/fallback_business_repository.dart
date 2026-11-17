import '../models/business.dart';
import '../models/business_draft.dart';
import '../models/category.dart';
import '../models/location_node.dart';
import '../models/review.dart';
import '../models/search.dart';
import 'business_repository.dart';

/// Uses Supabase when it is healthy, and the bundled demo catalogue otherwise.
///
/// This is deliberately read-only for now: publishing stays local until phone
/// auth and Storage are live. The fallback keeps the app usable while the remote
/// migrations are being applied.
class FallbackBusinessRepository implements BusinessRepository {
  FallbackBusinessRepository({
    required this.primary,
    required this.fallback,
    this.publishWithPrimary = false,
  });

  final BusinessRepository primary;
  final BusinessRepository fallback;

  /// Publishing only uses Supabase once real phone auth is enabled. Otherwise
  /// there is no authenticated owner for the row, so the demo repository is the
  /// safe local target.
  final bool publishWithPrimary;

  @override
  Future<SearchPage> search(
    SearchQuery query, {
    int page = 0,
    int pageSize = 20,
  }) {
    return _read(
      () => primary.search(query, page: page, pageSize: pageSize),
      () => fallback.search(query, page: page, pageSize: pageSize),
    );
  }

  @override
  Future<Business?> byId(String id) {
    return _read(
      () => primary.byId(id),
      () => fallback.byId(id),
    );
  }

  @override
  Future<List<Business>> featured(AreaScope? area, {int limit = 5}) {
    return _read(
      () => primary.featured(area, limit: limit),
      () => fallback.featured(area, limit: limit),
    );
  }

  @override
  Future<List<Business>> allPublished() {
    return _read(
      primary.allPublished,
      fallback.allPublished,
    );
  }

  @override
  Future<List<Review>> reviewsFor(String businessId) {
    return _read(
      () => primary.reviewsFor(businessId),
      () => fallback.reviewsFor(businessId),
    );
  }

  @override
  Future<List<Category>> categories() async {
    try {
      final categories = await primary.categories();
      if (categories.isNotEmpty) return categories;
    } catch (_) {
      // Fall through to the bundled taxonomy.
    }
    return fallback.categories();
  }

  @override
  Future<Business> publish(BusinessDraft draft, {required String ownerId}) {
    if (publishWithPrimary) {
      return primary.publish(draft, ownerId: ownerId);
    }
    // Demo auth has no Supabase user, so a remote insert would be rejected by
    // RLS. Keep the local draft visible until phone auth is enabled.
    return fallback.publish(draft, ownerId: ownerId);
  }

  Future<T> _read<T>(
    Future<T> Function() primaryCall,
    Future<T> Function() fallbackCall,
  ) async {
    try {
      return await primaryCall();
    } catch (_) {
      return fallbackCall();
    }
  }
}
