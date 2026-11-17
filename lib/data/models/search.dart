import '../models/business.dart';
import '../models/listing.dart';
import '../models/location_node.dart';

enum SortOption {
  bestMatch,
  fastestResponse,
  highestRated,
  newest;

  String get label => switch (this) {
        SortOption.bestMatch => 'Best match',
        SortOption.fastestResponse => 'Fastest response',
        SortOption.highestRated => 'Highest rated',
        SortOption.newest => 'Newest',
      };
}

class SearchFilters {
  const SearchFilters({
    this.listingType,
    this.availability,
    this.adminVerifiedOnly = false,
    this.minRating,
  });

  final ListingType? listingType; // product or service
  final Availability? availability;
  final bool adminVerifiedOnly;
  final double? minRating;

  int get activeCount {
    var count = 0;
    if (listingType != null) count++;
    if (availability != null) count++;
    if (adminVerifiedOnly) count++;
    if (minRating != null) count++;
    return count;
  }

  SearchFilters copyWith({
    ListingType? listingType,
    Availability? availability,
    bool? adminVerifiedOnly,
    double? minRating,
    bool clearListingType = false,
    bool clearAvailability = false,
    bool clearMinRating = false,
  }) {
    return SearchFilters(
      listingType: clearListingType ? null : (listingType ?? this.listingType),
      availability:
          clearAvailability ? null : (availability ?? this.availability),
      adminVerifiedOnly: adminVerifiedOnly ?? this.adminVerifiedOnly,
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
    );
  }
}

class SearchQuery {
  const SearchQuery({
    this.keyword = '',
    this.categoryId,
    required this.area,
    this.filters = const SearchFilters(),
    this.sort = SortOption.bestMatch,
    this.includeNearby = false,
  });

  final String keyword;
  final String? categoryId;
  final AreaScope area;
  final SearchFilters filters;
  final SortOption sort;

  /// Set by the "Show nearby too" action on the empty state.
  final bool includeNearby;

  SearchQuery copyWith({
    String? keyword,
    String? categoryId,
    AreaScope? area,
    SearchFilters? filters,
    SortOption? sort,
    bool? includeNearby,
    bool clearCategory = false,
  }) {
    return SearchQuery(
      keyword: keyword ?? this.keyword,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      area: area ?? this.area,
      filters: filters ?? this.filters,
      sort: sort ?? this.sort,
      includeNearby: includeNearby ?? this.includeNearby,
    );
  }

  String get label {
    final trimmed = keyword.trim();
    if (trimmed.isNotEmpty) return '"$trimmed"';
    return 'everything nearby';
  }
}

class BusinessHit {
  const BusinessHit({required this.business, this.isNearby = false});

  final Business business;
  final bool isNearby;
}

class SearchPage {
  const SearchPage({
    required this.hits,
    required this.totalExact,
    required this.hasMore,
    this.totalNearby = 0,
  });

  final List<BusinessHit> hits;
  final int totalExact;
  final int totalNearby;
  final bool hasMore;
}

class SearchState {
  const SearchState({
    required this.hits,
    required this.totalExact,
    required this.hasMore,
    this.totalNearby = 0,
    this.page = 0,
  });

  final List<BusinessHit> hits;
  final int totalExact;
  final int totalNearby;
  final bool hasMore;
  final int page;

  SearchState append(SearchPage next) {
    return SearchState(
      hits: [...hits, ...next.hits],
      totalExact: next.totalExact,
      totalNearby: next.totalNearby,
      hasMore: next.hasMore,
      page: page + 1,
    );
  }
}
