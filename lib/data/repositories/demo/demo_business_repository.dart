import '../../demo/demo_catalog.dart';
import '../../demo/demo_locations.dart';
import '../../models/business.dart';
import '../../models/business_draft.dart';
import '../../models/category.dart';
import '../../models/listing.dart';
import '../../models/location_node.dart';
import '../../models/review.dart';
import '../../models/search.dart';
import '../../search/search_engine.dart';
import '../business_repository.dart';
import '../location_repository.dart';

class DemoBusinessRepository implements BusinessRepository {
  DemoBusinessRepository(this._catalog, this._locations);

  final DemoCatalog _catalog;
  final LocationRepository _locations;

  @override
  Future<SearchPage> search(
    SearchQuery query, {
    int page = 0,
    int pageSize = 20,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    return searchBusinesses(
      query: query,
      businesses: _catalog.businesses,
      categories: _catalog.categories,
      locations: _locations,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Business?> byId(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _catalog.businessById(id);
  }

  @override
  Future<List<Business>> featured(AreaScope? area, {int limit = 5}) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final published = _catalog.businesses
        .where((business) => business.isPublished)
        .toList();
    if (area == null) {
      published.sort((a, b) => b.lightScore.compareTo(a.lightScore));
      return published.take(limit).toList();
    }
    final page = searchBusinesses(
      query: SearchQuery(area: area),
      businesses: published,
      categories: _catalog.categories,
      locations: _locations,
      pageSize: limit,
    );
    return page.hits.map((hit) => hit.business).toList();
  }

  @override
  Future<List<Business>> allPublished() async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return _catalog.businesses
        .where((business) => business.isPublished)
        .toList();
  }

  @override
  Future<List<Review>> reviewsFor(String businessId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final reviews = _catalog.reviews
        .where((review) => review.businessId == businessId)
        .toList();
    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reviews;
  }

  @override
  Future<List<Category>> categories() async => _catalog.categories;

  @override
  Future<Business> publish(
    BusinessDraft draft, {
    required String ownerId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final baseSlug = DemoLocations.slugify(draft.name);
    var slug = baseSlug;
    var suffix = 2;
    while (_catalog.businesses.any((business) => business.slug == slug)) {
      slug = '$baseSlug-$suffix';
      suffix++;
    }

    final completeness = _estimateCompleteness(draft);
    final category = draft.categoryIds.isEmpty
        ? null
        : _catalog.categoryById(draft.categoryIds.first);
    final isProduct = category?.kind == CategoryKind.product;
    final listings = <Listing>[];
    if (draft.listingTitle.trim().isNotEmpty) {
      listings.add(
        Listing(
          id: '$slug-listing',
          businessId: slug,
          type: isProduct ? ListingType.product : ListingType.service,
          title: draft.listingTitle.trim(),
          description: draft.description.trim(),
          priceType: draft.listingPrice == null
              ? PriceType.onRequest
              : PriceType.fixed,
          price: draft.listingPrice,
          images: draft.photos,
          categoryId: category?.id,
        ),
      );
    }
    final business = Business(
      id: slug,
      ownerId: ownerId,
      name: draft.name.trim(),
      description: draft.description.trim(),
      categoryIds: draft.categoryIds,
      stateId: draft.stateId!,
      lgaId: draft.lgaId!,
      neighbourhoodId: draft.neighbourhoodId,
      baseArea: draft.baseArea.trim(),
      address: draft.address.trim().isEmpty ? null : draft.address.trim(),
      operatingModel: draft.operatingModel!,
      serviceAreaLgaIds: draft.operatingModel == OperatingModel.mobile
          ? draft.serviceAreaLgaIds
          : const [],
      availability: Availability.availableToday,
      verificationLevel: 1,
      lightScore: Business.computeLightScore(
        completeness: completeness,
        medianResponseMinutes: 0,
        rating: 0,
        reviewCount: 0,
        verificationLevel: 1,
      ),
      completeness: completeness,
      medianResponseMinutes: 0,
      rating: 0,
      reviewCount: 0,
      photos: draft.photos,
      listings: listings,
      hasProduct: isProduct,
      hasService: !isProduct,
      isPublished: true,
      createdAt: DateTime.now(),
      whatsappNumber: draft.whatsappNumber,
      phoneNumber: draft.phoneNumber,
      openingHours: draft.openingHours,
      slug: slug,
      ownerName: draft.ownerName.trim().isEmpty ? null : draft.ownerName.trim(),
      ownerBio: draft.ownerBio,
      ownerPhotoUrl: draft.ownerPhotoUrl,
    );

    _catalog.publish(business);
    return business;
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
}
