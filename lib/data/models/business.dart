import 'listing.dart';

enum OperatingModel {
  fixedLocation,
  mobile;

  String get label => switch (this) {
    OperatingModel.fixedLocation => 'Fixed location',
    OperatingModel.mobile => 'Mobile / on-site',
  };

  String get shortLabel => switch (this) {
    OperatingModel.fixedLocation => 'At their place',
    OperatingModel.mobile => 'Comes to you',
  };
}

enum Availability {
  availableToday,
  busyThisWeek,
  notTakingJobs;

  String get label => switch (this) {
    Availability.availableToday => 'Available today',
    Availability.busyThisWeek => 'Busy this week',
    Availability.notTakingJobs => 'Not taking jobs',
  };

  static Availability parse(String? raw) => Availability.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => Availability.availableToday,
  );
}

enum LightBand {
  starting,
  growing,
  shining;

  String get label => switch (this) {
    LightBand.starting => 'Starting',
    LightBand.growing => 'Growing',
    LightBand.shining => 'Shining',
  };

  String get explanation => switch (this) {
    LightBand.starting =>
      'New or still completing the profile. Check the reviews and chat first.',
    LightBand.growing =>
      'Building a track record. Profile details and responses are improving.',
    LightBand.shining =>
      'Complete profile, fast replies and a strong review record.',
  };
}

class Business {
  const Business({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.categoryIds,
    required this.stateId,
    required this.lgaId,
    required this.baseArea,
    this.address,
    required this.operatingModel,
    required this.serviceAreaLgaIds,
    required this.availability,
    required this.verificationLevel,
    required this.lightScore,
    required this.completeness,
    required this.medianResponseMinutes,
    required this.rating,
    required this.reviewCount,
    required this.photos,
    required this.listings,
    required this.hasProduct,
    required this.hasService,
    required this.isPublished,
    required this.createdAt,
    this.neighbourhoodId,
    this.whatsappNumber,
    this.phoneNumber,
    this.openingHours,
    this.slug,
    this.ownerName,
    this.ownerPhotoUrl,
    this.ownerBio,
  });

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final List<String> categoryIds;
  final String stateId;
  final String lgaId;
  final String? neighbourhoodId;
  final String baseArea;

  /// Optional public shop or street address supplied by the owner. Discovery
  /// never depends on this field.
  final String? address;
  final OperatingModel operatingModel;
  final List<String> serviceAreaLgaIds;
  final Availability availability;
  final int verificationLevel;
  final int lightScore;
  final double completeness;
  final int medianResponseMinutes;
  final double rating;
  final int reviewCount;
  final List<String> photos;
  final List<Listing> listings;
  final bool hasProduct;
  final bool hasService;
  final bool isPublished;
  final DateTime createdAt;
  final String? whatsappNumber;
  final String? phoneNumber;
  final String? openingHours;
  final String? slug;
  final String? ownerName;
  final String? ownerPhotoUrl;
  final String? ownerBio;

  String get primaryCategoryId => categoryIds.first;

  bool get isAdminVerified => verificationLevel >= 2;
  bool get isPhoneVerified => verificationLevel >= 1;

  LightBand get lightBand {
    if (lightScore >= 70) return LightBand.shining;
    if (lightScore >= 40) return LightBand.growing;
    return LightBand.starting;
  }

  bool servesLga(String lgaId) {
    if (operatingModel == OperatingModel.fixedLocation) {
      return this.lgaId == lgaId;
    }
    return serviceAreaLgaIds.contains(lgaId);
  }

  bool get hasEnoughPhotos => photos.length >= 3;

  Business copyWith({
    int? verificationLevel,
    int? lightScore,
    double? completeness,
    Availability? availability,
    bool? isPublished,
    List<String>? photos,
    List<Listing>? listings,
    String? address,
  }) {
    return Business(
      id: id,
      ownerId: ownerId,
      name: name,
      description: description,
      categoryIds: categoryIds,
      stateId: stateId,
      lgaId: lgaId,
      neighbourhoodId: neighbourhoodId,
      baseArea: baseArea,
      address: address ?? this.address,
      operatingModel: operatingModel,
      serviceAreaLgaIds: serviceAreaLgaIds,
      availability: availability ?? this.availability,
      verificationLevel: verificationLevel ?? this.verificationLevel,
      lightScore: lightScore ?? this.lightScore,
      completeness: completeness ?? this.completeness,
      medianResponseMinutes: medianResponseMinutes,
      rating: rating,
      reviewCount: reviewCount,
      photos: photos ?? this.photos,
      listings: listings ?? this.listings,
      hasProduct: hasProduct,
      hasService: hasService,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt,
      whatsappNumber: whatsappNumber,
      phoneNumber: phoneNumber,
      openingHours: openingHours,
      slug: slug,
      ownerName: ownerName,
      ownerPhotoUrl: ownerPhotoUrl,
      ownerBio: ownerBio,
    );
  }

  /// Starting weights from the PRD. Reviews only count from 5 upwards.
  static int computeLightScore({
    required double completeness,
    required int medianResponseMinutes,
    required double rating,
    required int reviewCount,
    required int verificationLevel,
  }) {
    final completenessPart = completeness.clamp(0.0, 1.0) * 25;
    final responsePart = medianResponseMinutes <= 0
        ? 0.0
        : (1 - (medianResponseMinutes / 240)).clamp(0.0, 1.0) * 20;
    final reviewPart = reviewCount < 5
        ? 0.0
        : (rating / 5).clamp(0.0, 1.0) *
              (reviewCount / 20).clamp(0.0, 1.0) *
              25;
    final phonePart = verificationLevel >= 1 ? 15.0 : 0.0;
    final adminPart = verificationLevel >= 2 ? 15.0 : 0.0;
    return (completenessPart +
            responsePart +
            reviewPart +
            phonePart +
            adminPart)
        .round()
        .clamp(0, 100);
  }

  factory Business.fromJson(Map<String, dynamic> json, String id) {
    return Business(
      id: id,
      ownerId: (json['ownerId'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      categoryIds: List<String>.from(json['categoryIds'] as List? ?? const []),
      stateId: (json['stateId'] as String?) ?? '',
      lgaId: (json['lgaId'] as String?) ?? '',
      neighbourhoodId: json['neighbourhoodId'] as String?,
      baseArea: (json['baseArea'] as String?) ?? '',
      address: json['address'] as String?,
      operatingModel: OperatingModel.values.firstWhere(
        (model) => model.name == json['operatingModel'],
        orElse: () => OperatingModel.fixedLocation,
      ),
      serviceAreaLgaIds: List<String>.from(
        json['serviceAreaLgaIds'] as List? ?? const [],
      ),
      availability: Availability.parse(json['availability'] as String?),
      verificationLevel: (json['verificationLevel'] as num?)?.toInt() ?? 1,
      lightScore: (json['lightScore'] as num?)?.toInt() ?? 0,
      completeness: (json['completeness'] as num?)?.toDouble() ?? 0,
      medianResponseMinutes:
          (json['medianResponseMinutes'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      photos: List<String>.from(json['photos'] as List? ?? const []),
      listings: const [],
      hasProduct: (json['hasProduct'] as bool?) ?? false,
      hasService: (json['hasService'] as bool?) ?? false,
      isPublished: (json['isPublished'] as bool?) ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      whatsappNumber: json['whatsappNumber'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      openingHours: json['openingHours'] as String?,
      slug: json['slug'] as String?,
      ownerName: json['ownerName'] as String?,
      ownerPhotoUrl: json['ownerPhotoUrl'] as String?,
      ownerBio: json['ownerBio'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'ownerId': ownerId,
    'name': name,
    'description': description,
    'categoryIds': categoryIds,
    'stateId': stateId,
    'lgaId': lgaId,
    'neighbourhoodId': neighbourhoodId,
    'baseArea': baseArea,
    'address': address,
    'operatingModel': operatingModel.name,
    'serviceAreaLgaIds': serviceAreaLgaIds,
    'availability': availability.name,
    'verificationLevel': verificationLevel,
    'lightScore': lightScore,
    'completeness': completeness,
    'medianResponseMinutes': medianResponseMinutes,
    'rating': rating,
    'reviewCount': reviewCount,
    'photos': photos,
    'hasProduct': hasProduct,
    'hasService': hasService,
    'isPublished': isPublished,
    'createdAt': createdAt.toIso8601String(),
    'whatsappNumber': whatsappNumber,
    'phoneNumber': phoneNumber,
    'openingHours': openingHours,
    'slug': slug,
    'ownerName': ownerName,
    'ownerPhotoUrl': ownerPhotoUrl,
    'ownerBio': ownerBio,
  };
}
