import 'business.dart';

/// Editable draft used by business registration. Kept in the data layer so
/// repositories can publish it without importing feature code.
class BusinessDraft {
  const BusinessDraft({
    this.name = '',
    this.description = '',
    this.categoryIds = const [],
    this.stateId,
    this.lgaId,
    this.neighbourhoodId,
    this.baseArea = '',
    this.address = '',
    this.operatingModel,
    this.serviceAreaLgaIds = const [],
    this.whatsappNumber,
    this.phoneNumber,
    this.photos = const [],
    this.phoneVerified = false,
    this.openingHours,
    this.ownerName = '',
    this.ownerBio,
    this.ownerPhotoUrl,
    this.listingTitle = '',
    this.listingPrice,
  });

  final String name;
  final String description;
  final List<String> categoryIds;
  final String? stateId;
  final String? lgaId;
  final String? neighbourhoodId;
  final String baseArea;

  /// Optional public shop/street address. Empty means not shown.
  final String address;
  final OperatingModel? operatingModel;
  final List<String> serviceAreaLgaIds;
  final String? whatsappNumber;
  final String? phoneNumber;
  final List<String> photos;
  final bool phoneVerified;
  final String? openingHours;
  final String ownerName;
  final String? ownerBio;
  final String? ownerPhotoUrl;

  /// Optional first listing created with the business. Product sellers use this
  /// so their item appears in the Products section immediately.
  final String listingTitle;
  final int? listingPrice;

  BusinessDraft copyWith({
    String? name,
    String? description,
    List<String>? categoryIds,
    String? stateId,
    String? lgaId,
    String? neighbourhoodId,
    String? baseArea,
    String? address,
    OperatingModel? operatingModel,
    List<String>? serviceAreaLgaIds,
    String? whatsappNumber,
    String? phoneNumber,
    List<String>? photos,
    bool? phoneVerified,
    String? openingHours,
    String? ownerName,
    String? ownerBio,
    String? ownerPhotoUrl,
    String? listingTitle,
    int? listingPrice,
    bool clearListingPrice = false,
    bool clearState = false,
    bool clearLga = false,
    bool clearNeighbourhood = false,
    bool clearOperatingModel = false,
  }) {
    return BusinessDraft(
      name: name ?? this.name,
      description: description ?? this.description,
      categoryIds: categoryIds ?? this.categoryIds,
      stateId: clearState ? null : (stateId ?? this.stateId),
      lgaId: clearState || clearLga ? null : (lgaId ?? this.lgaId),
      neighbourhoodId: clearState || clearLga || clearNeighbourhood
          ? null
          : (neighbourhoodId ?? this.neighbourhoodId),
      baseArea: baseArea ?? this.baseArea,
      address: address ?? this.address,
      operatingModel: clearOperatingModel
          ? null
          : (operatingModel ?? this.operatingModel),
      serviceAreaLgaIds: serviceAreaLgaIds ?? this.serviceAreaLgaIds,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photos: photos ?? this.photos,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      openingHours: openingHours ?? this.openingHours,
      ownerName: ownerName ?? this.ownerName,
      ownerBio: ownerBio ?? this.ownerBio,
      ownerPhotoUrl: ownerPhotoUrl ?? this.ownerPhotoUrl,
      listingTitle: listingTitle ?? this.listingTitle,
      listingPrice: clearListingPrice
          ? null
          : (listingPrice ?? this.listingPrice),
    );
  }
}
