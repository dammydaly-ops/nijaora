import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/services/photo_service.dart';
import '../../models/business.dart';
import '../../models/business_draft.dart';
import '../../models/category.dart';
import '../../models/listing.dart';
import '../../models/location_node.dart';
import '../../models/review.dart';
import '../../models/search.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/location_repository.dart';
import '../../search/search_engine.dart';

/// Read-first Supabase repository.
///
/// Publishing still goes through the local/demo repository until phone auth and
/// Storage are live. The wrapper in `providers.dart` falls back to the demo
/// catalogue if a query fails, so the app remains usable while migrations are
/// being applied.
class SupabaseBusinessRepository implements BusinessRepository {
  SupabaseBusinessRepository(
    this._client,
    this._locations, {
    PhotoService? photos,
  }) : _photos = photos ?? PhotoService();

  final SupabaseClient _client;
  final LocationRepository _locations;
  final PhotoService _photos;

  static const _businessSelect = '''
    id,
    owner_id,
    slug,
    name,
    description,
    primary_category_id,
    state_id,
    lga_id,
    neighbourhood_id,
    base_area,
    address,
    operating_model,
    service_area_lga_ids,
    availability,
    verification_level,
    light_score,
    completeness,
    median_response_minutes,
    rating,
    review_count,
    photos,
    owner_photo_url,
    owner_bio,
    has_product,
    has_service,
    is_published,
    whatsapp_number,
    phone_number,
    opening_hours,
    created_at,
    business_categories(category_id, is_primary),
    listings(
      id,
      business_id,
      category_id,
      type,
      title,
      description,
      price_type,
      price,
      images,
      is_available
    ),
    profiles!businesses_owner_id_fkey(display_name, avatar_url)
  ''';

  @override
  Future<SearchPage> search(
    SearchQuery query, {
    int page = 0,
    int pageSize = 20,
  }) async {
    final businesses = await allPublished();
    final categories = await this.categories();
    return searchBusinesses(
      query: query,
      businesses: businesses,
      categories: categories,
      locations: _locations,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Business?> byId(String id) async {
    final row = await _client
        .from('businesses')
        .select(_businessSelect)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _businessFromRow(row);
  }

  @override
  Future<List<Business>> featured(AreaScope? area, {int limit = 5}) async {
    var query = _client
        .from('businesses')
        .select(_businessSelect)
        .eq('is_published', true)
        .eq('is_suspended', false);

    if (area != null) {
      query = query.eq('state_id', area.stateId);
      final lgaId = area.lgaId;
      if (lgaId != null) {
        query = query.or('lga_id.eq.$lgaId,service_area_lga_ids.cs.{$lgaId}');
      }
    }

    final rows = await query
        .order('light_score', ascending: false)
        .limit(limit);
    return rows.map(_businessFromRow).toList(growable: false);
  }

  @override
  Future<List<Business>> allPublished() async {
    final rows = await _client
        .from('businesses')
        .select(_businessSelect)
        .eq('is_published', true)
        .eq('is_suspended', false)
        .order('created_at', ascending: false);
    return rows.map(_businessFromRow).toList(growable: false);
  }

  @override
  Future<List<Review>> reviewsFor(String businessId) async {
    final rows = await _client
        .from('reviews')
        .select(
          'id, business_id, author_id, author_name, rating, text, reply, '
          'created_at',
        )
        .eq('business_id', businessId)
        .eq('is_hidden', false)
        .order('created_at', ascending: false);
    return rows.map(_reviewFromRow).toList(growable: false);
  }

  @override
  Future<List<Category>> categories() async {
    final rows = await _client
        .from('categories')
        .select('id, parent_id, name, description, synonyms, kind, sort_order')
        .eq('active', true)
        .order('sort_order', ascending: true)
        .order('name', ascending: true);
    return rows.map(_categoryFromRow).toList(growable: false);
  }

  @override
  Future<Business> publish(
    BusinessDraft draft, {
    required String ownerId,
  }) async {
    final category = draft.categoryIds.isEmpty
        ? null
        : await _categoryById(draft.categoryIds.first);
    final isProduct = category?.kind == CategoryKind.product;
    final completeness = _estimateCompleteness(draft);
    final lightScore =
        Business.computeLightScore(
          completeness: completeness,
          medianResponseMinutes: 0,
          rating: 0,
          reviewCount: 0,
          verificationLevel: 1,
        ) /
        100;

    try {
      final slug = await _availableSlug(draft.name);
      final inserted = await _client
          .from('businesses')
          .insert({
            'owner_id': ownerId,
            'slug': slug,
            'name': draft.name.trim(),
            'description': draft.description.trim(),
            'primary_category_id': draft.categoryIds.isEmpty
                ? null
                : draft.categoryIds.first,
            'state_id': draft.stateId,
            'lga_id': draft.lgaId,
            'neighbourhood_id': draft.neighbourhoodId,
            'base_area': draft.baseArea.trim(),
            'address': draft.address.trim().isEmpty
                ? null
                : draft.address.trim(),
            'operating_model': draft.operatingModel == OperatingModel.mobile
                ? 'mobile'
                : 'fixed_location',
            'service_area_lga_ids':
                draft.operatingModel == OperatingModel.mobile
                ? draft.serviceAreaLgaIds
                : const <String>[],
            'availability': 'available_today',
            'verification_level': 1,
            'light_score': lightScore,
            'completeness': completeness,
            'median_response_minutes': 0,
            'rating': 0,
            'review_count': 0,
            'photos': const <String>[],
            'owner_photo_url': draft.ownerPhotoUrl,
            'owner_bio': draft.ownerBio,
            'has_product': isProduct,
            'has_service': !isProduct,
            'is_published': true,
            'whatsapp_number': draft.whatsappNumber,
            'phone_number': draft.phoneNumber,
            'opening_hours': draft.openingHours,
          })
          .select('id')
          .single();

      final businessId = inserted['id'].toString();
      final photoUrls = await _uploadPhotos(
        businessId: businessId,
        ownerId: ownerId,
        draft: draft,
      );

      await _client
          .from('businesses')
          .update({
            'photos': photoUrls.portfolio,
            'owner_photo_url': photoUrls.owner,
          })
          .eq('id', businessId);

      final profileUpdate = <String, dynamic>{
        if (draft.ownerName.trim().isNotEmpty)
          'display_name': draft.ownerName.trim(),
        if (photoUrls.owner != null) 'avatar_url': photoUrls.owner,
      };
      if (profileUpdate.isNotEmpty) {
        await _client.from('profiles').update(profileUpdate).eq('id', ownerId);
      }

      if (draft.categoryIds.isNotEmpty) {
        await _client.from('business_categories').insert([
          for (var i = 0; i < draft.categoryIds.length; i++)
            {
              'business_id': businessId,
              'category_id': draft.categoryIds[i],
              'is_primary': i == 0,
            },
        ]);
      }

      if (draft.listingTitle.trim().isNotEmpty) {
        await _client.from('listings').insert({
          'business_id': businessId,
          'category_id': draft.categoryIds.isEmpty
              ? null
              : draft.categoryIds.first,
          'type': isProduct ? 'product' : 'service',
          'title': draft.listingTitle.trim(),
          'description': draft.description.trim(),
          'price_type': draft.listingPrice == null ? 'on_request' : 'fixed',
          'price': draft.listingPrice,
          'images': photoUrls.portfolio,
          'is_available': true,
        });
      }

      final published = await byId(businessId);
      if (published == null) {
        throw const AppFailure(
          'Your business was saved but we could not reload it. Try again.',
        );
      }
      return published;
    } on AppFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw AppFailure(_publishMessage(error));
    } on StorageException catch (error) {
      throw AppFailure(
        'We could not upload your photos. Check your connection and try again '
        '(${error.statusCode}).',
      );
    } catch (_) {
      throw const AppFailure(
        'We could not publish your profile. Check your connection and try '
        'again.',
      );
    }
  }

  Future<Category?> _categoryById(String id) async {
    final row = await _client
        .from('categories')
        .select('id, parent_id, name, description, synonyms, kind')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _categoryFromRow(row);
  }

  Future<String> _availableSlug(String name) async {
    final base = _slugify(name);
    var slug = base;
    for (var suffix = 2; suffix < 50; suffix++) {
      final existing = await _client
          .from('businesses')
          .select('id')
          .eq('slug', slug)
          .maybeSingle();
      if (existing == null) return slug;
      slug = '$base-$suffix';
    }
    return '$base-${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<({List<String> portfolio, String? owner})> _uploadPhotos({
    required String businessId,
    required String ownerId,
    required BusinessDraft draft,
  }) async {
    final portfolio = <String>[];
    for (var i = 0; i < draft.photos.length; i++) {
      try {
        portfolio.add(
          await _photos.uploadBusinessPhoto(
            businessId: businessId,
            dataUrl: draft.photos[i],
            fileName: 'photo-${i + 1}.jpg',
          ),
        );
      } catch (_) {
        // Keep the local data URL rather than losing the whole registration
        // because Storage is not configured yet.
        portfolio.add(draft.photos[i]);
      }
    }

    var owner = draft.ownerPhotoUrl;
    if (owner != null && owner.isNotEmpty) {
      try {
        owner = await _photos.uploadOwnerPhoto(
          ownerId: ownerId,
          dataUrl: owner,
          fileName: 'avatar.jpg',
        );
      } catch (_) {
        // Keep the local data URL.
      }
    }
    return (portfolio: portfolio, owner: owner);
  }

  double _estimateCompleteness(BusinessDraft draft) {
    var score = 0.0;
    if (draft.name.trim().length >= 2) score += 0.1;
    if (draft.description.trim().length >= 20) score += 0.15;
    if (draft.categoryIds.isNotEmpty) score += 0.1;
    if (draft.stateId != null && draft.lgaId != null) score += 0.15;
    if (draft.baseArea.trim().isNotEmpty) score += 0.1;
    if (draft.operatingModel != null) score += 0.05;
    if (draft.serviceAreaLgaIds.length > 1) score += 0.05;
    if (draft.whatsappNumber != null) score += 0.05;
    if (draft.photos.length >= 3) score += 0.2;
    return score.clamp(0.0, 1.0).toDouble();
  }

  String _slugify(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'business' : slug;
  }

  String _publishMessage(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (message.contains('duplicate') || message.contains('unique')) {
      return 'That business name is already in use. Try a slightly different '
          'name.';
    }
    if (message.contains('row-level security') || message.contains('policy')) {
      return 'Your session is not allowed to publish yet. Sign out and sign '
          'in again.';
    }
    return 'We could not save your business. Please try again.';
  }

  Business _businessFromRow(Map<String, dynamic> row) {
    final categoryRows = (row['business_categories'] as List?) ?? const [];
    final categoryIds = <String>[];
    for (final category in categoryRows) {
      if (category is! Map) continue;
      final id = category['category_id'];
      if (id is String && id.isNotEmpty) categoryIds.add(id);
    }
    final primaryCategoryId = row['primary_category_id'] as String?;
    if (primaryCategoryId != null &&
        primaryCategoryId.isNotEmpty &&
        !categoryIds.contains(primaryCategoryId)) {
      categoryIds.insert(0, primaryCategoryId);
    }

    final listingRows = (row['listings'] as List?) ?? const [];
    final listings = <Listing>[];
    for (final listing in listingRows) {
      if (listing is Map<String, dynamic>) {
        listings.add(_listingFromRow(listing));
      }
    }

    final profile = _asMap(row['profiles']);
    final ownerName = _nonEmpty(profile?['display_name'] as String?);
    final ownerPhoto =
        _nonEmpty(row['owner_photo_url'] as String?) ??
        _nonEmpty(profile?['avatar_url'] as String?);

    return Business(
      id: row['id'].toString(),
      ownerId: row['owner_id'].toString(),
      name: (row['name'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      categoryIds: categoryIds,
      stateId: (row['state_id'] as String?) ?? '',
      lgaId: (row['lga_id'] as String?) ?? '',
      neighbourhoodId: row['neighbourhood_id'] as String?,
      baseArea: (row['base_area'] as String?) ?? '',
      address: _nonEmpty(row['address'] as String?),
      operatingModel: _operatingModel(row['operating_model'] as String?),
      serviceAreaLgaIds: List<String>.from(
        row['service_area_lga_ids'] as List? ?? const [],
      ),
      availability: _availability(row['availability'] as String?),
      verificationLevel: (row['verification_level'] as num?)?.toInt() ?? 1,
      lightScore: (((row['light_score'] as num?)?.toDouble() ?? 0) * 100)
          .round(),
      completeness: (row['completeness'] as num?)?.toDouble() ?? 0,
      medianResponseMinutes:
          (row['median_response_minutes'] as num?)?.toInt() ?? 0,
      rating: (row['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
      photos: List<String>.from(row['photos'] as List? ?? const []),
      listings: listings,
      hasProduct: (row['has_product'] as bool?) ?? false,
      hasService: (row['has_service'] as bool?) ?? false,
      isPublished: (row['is_published'] as bool?) ?? false,
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      whatsappNumber: row['whatsapp_number'] as String?,
      phoneNumber: row['phone_number'] as String?,
      openingHours: row['opening_hours'] as String?,
      slug: row['slug'] as String?,
      ownerName: ownerName,
      ownerPhotoUrl: ownerPhoto,
      ownerBio: _nonEmpty(row['owner_bio'] as String?),
    );
  }

  Listing _listingFromRow(Map<String, dynamic> row) {
    return Listing(
      id: row['id'].toString(),
      businessId: row['business_id'].toString(),
      type: (row['type'] as String?) == 'product'
          ? ListingType.product
          : ListingType.service,
      title: (row['title'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      priceType: _priceType(row['price_type'] as String?),
      price: (row['price'] as num?)?.toInt(),
      images: List<String>.from(row['images'] as List? ?? const []),
      isAvailable: (row['is_available'] as bool?) ?? true,
      categoryId: row['category_id'] as String?,
    );
  }

  Review _reviewFromRow(Map<String, dynamic> row) {
    return Review(
      id: row['id'].toString(),
      businessId: row['business_id'].toString(),
      customerId: row['author_id']?.toString() ?? '',
      customerName: (row['author_name'] as String?) ?? 'Nijaora customer',
      rating: (row['rating'] as num?)?.toInt() ?? 0,
      text: (row['text'] as String?) ?? '',
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      ownerReply: _nonEmpty(row['reply'] as String?),
    );
  }

  Category _categoryFromRow(Map<String, dynamic> row) {
    return Category(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      synonyms: List<String>.from(row['synonyms'] as List? ?? const []),
      parentId: row['parent_id'] as String?,
      kind: (row['kind'] as String?) == 'product'
          ? CategoryKind.product
          : CategoryKind.service,
    );
  }

  OperatingModel _operatingModel(String? raw) =>
      raw == 'mobile' ? OperatingModel.mobile : OperatingModel.fixedLocation;

  Availability _availability(String? raw) {
    return switch (raw) {
      'busy_this_week' => Availability.busyThisWeek,
      'not_taking_jobs' => Availability.notTakingJobs,
      _ => Availability.availableToday,
    };
  }

  PriceType _priceType(String? raw) {
    return switch (raw) {
      'fixed' => PriceType.fixed,
      'from' => PriceType.from,
      'negotiable' => PriceType.negotiable,
      _ => PriceType.onRequest,
    };
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String? _nonEmpty(String? value) =>
      value == null || value.trim().isEmpty ? null : value;
}
