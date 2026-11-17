import 'dart:math' as math;

import '../models/business.dart';
import '../models/category.dart';
import '../models/location_node.dart';
import '../models/search.dart';
import '../repositories/location_repository.dart';

const _weights = {
  'relevance': 0.40,
  'area': 0.20,
  'completeness': 0.15,
  'response': 0.15,
  'rating': 0.10,
};

const _stopWords = {
  'a', 'an', 'the', 'in', 'for', 'me', 'i', 'need', 'near', 'and', 'of',
  'to', 'my', 'is', 'on', 'at', 'please', 'find', 'want', 'looking',
};

/// Deterministic v1 ranking. Kept pure so it can be unit-tested and later
/// mirrored by the search backend.
double businessScore({
  required Business business,
  required double relevance,
  required double areaScore,
  required bool neighbourhoodMatch,
}) {
  final responseScore = business.medianResponseMinutes <= 0
      ? 0.0
      : (1 - business.medianResponseMinutes / 240).clamp(0.0, 1.0);
  final ratingScore = business.reviewCount < 5
      ? 0.0
      : (business.rating / 5).clamp(0.0, 1.0) *
          (business.reviewCount / 20).clamp(0.0, 1.0);

  final score = _weights['relevance']! * relevance +
      _weights['area']! * areaScore +
      _weights['completeness']! * business.completeness.clamp(0.0, 1.0) +
      _weights['response']! * responseScore +
      _weights['rating']! * ratingScore;

  return (score + (neighbourhoodMatch ? 0.02 : 0)).clamp(0.0, 1.0).toDouble();
}

SearchPage searchBusinesses({
  required SearchQuery query,
  required List<Business> businesses,
  required List<Category> categories,
  required LocationRepository locations,
  int page = 0,
  int pageSize = 20,
}) {
  final exact = <_Scored>[];
  final nearby = <_Scored>[];
  final adjacent = query.area.lgaId == null
      ? const <LocationNode>[]
      : locations.adjacentLgas(query.area.lgaId!);

  for (final business in businesses) {
    if (!business.isPublished) continue;
    if (!_passesFilters(business, query, categories)) continue;

    final relevance = _relevance(business, query, categories, locations);
    if (relevance <= 0) continue;

    final area = _areaMatch(business, query, adjacent);
    if (area == _AreaMatch.none) continue;

    final isNearby = area == _AreaMatch.nearby;
    final neighbourhoodMatch = query.area.neighbourhoodId != null &&
        business.neighbourhoodId == query.area.neighbourhoodId;
    final score = businessScore(
      business: business,
      relevance: relevance,
      areaScore: switch (area) {
        _AreaMatch.exact => 1.0,
        _AreaMatch.state => 0.7,
        _AreaMatch.nearby => 0.4,
        _AreaMatch.none => 0.0,
      },
      neighbourhoodMatch: neighbourhoodMatch,
    );

    final hit = _Scored(business, score, isNearby);
    if (isNearby) {
      nearby.add(hit);
    } else {
      exact.add(hit);
    }
  }

  _sort(exact, query.sort);
  _sort(nearby, query.sort);

  final includeNearby = query.includeNearby || exact.length < 3;
  final combined = <_Scored>[
    ...exact,
    if (includeNearby) ...nearby,
  ];

  final start = page * pageSize;
  final end = math.min(start + pageSize, combined.length);
  final slice = start >= combined.length
      ? const <_Scored>[]
      : combined.sublist(start, end);

  return SearchPage(
    hits: slice
        .map((hit) => BusinessHit(business: hit.business, isNearby: hit.isNearby))
        .toList(),
    totalExact: exact.length,
    totalNearby: nearby.length,
    hasMore: end < combined.length,
  );
}

bool _passesFilters(
  Business business,
  SearchQuery query,
  List<Category> categories,
) {
  final filters = query.filters;
  if (query.categoryId != null &&
      !_matchesCategory(business, query.categoryId!, categories)) {
    return false;
  }
  if (filters.listingType != null) {
    final wantsProduct = filters.listingType!.name == 'product';
    if (wantsProduct && !business.hasProduct) return false;
    if (!wantsProduct && !business.hasService) return false;
  }
  if (filters.availability != null &&
      business.availability != filters.availability) {
    return false;
  }
  if (filters.adminVerifiedOnly && !business.isAdminVerified) return false;
  if (filters.minRating != null &&
      (business.reviewCount == 0 || business.rating < filters.minRating!)) {
    return false;
  }
  return true;
}

bool _matchesCategory(
  Business business,
  String categoryId,
  List<Category> categories,
) {
  if (business.categoryIds.contains(categoryId)) return true;

  Category? selected;
  for (final category in categories) {
    if (category.id == categoryId) {
      selected = category;
      break;
    }
  }
  if (selected == null || !selected.isParent) return false;

  for (final id in business.categoryIds) {
    for (final category in categories) {
      if (category.id == id && category.parentId == categoryId) return true;
    }
  }
  return false;
}

double _relevance(
  Business business,
  SearchQuery query,
  List<Category> categories,
  LocationRepository locations,
) {
  final tokens = _tokens(query.keyword);
  if (tokens.isEmpty) return 1;

  final name = business.name.toLowerCase();
  final description = business.description.toLowerCase();
  final area = business.baseArea.toLowerCase();
  final lga = (locations.byId(business.lgaId)?.name ?? '').toLowerCase();
  final listings = business.listings
      .map((listing) => '${listing.title} ${listing.description}'.toLowerCase())
      .join(' ');
  final categoryTerms = <String>[];
  for (final id in business.categoryIds) {
    for (final category in categories) {
      if (category.id == id) {
        categoryTerms.addAll(category.searchableTerms);
        if (category.parentId != null) {
          for (final parent in categories) {
            if (parent.id == category.parentId) {
              categoryTerms.addAll(parent.searchableTerms);
            }
          }
        }
      }
    }
  }
  final categoriesText = categoryTerms.join(' ').toLowerCase();

  var total = 0.0;
  for (final token in tokens) {
    var best = 0.0;
    if (name.contains(token)) best = 1.0;
    if (categoriesText.contains(token)) best = math.max(best, 0.85);
    if (listings.contains(token)) best = math.max(best, 0.6);
    if (description.contains(token)) best = math.max(best, 0.45);
    if (area.contains(token) || lga.contains(token)) {
      best = math.max(best, 0.3);
    }
    total += best;
  }
  return total / tokens.length;
}

List<String> _tokens(String keyword) {
  return keyword
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.length > 1 && !_stopWords.contains(token))
      .toList();
}

enum _AreaMatch { exact, nearby, state, none }

_AreaMatch _areaMatch(
  Business business,
  SearchQuery query,
  List<LocationNode> adjacent,
) {
  if (business.stateId != query.area.stateId) return _AreaMatch.none;

  final lgaId = query.area.lgaId;
  if (lgaId == null) return _AreaMatch.state;

  if (business.servesLga(lgaId)) return _AreaMatch.exact;
  for (final neighbour in adjacent) {
    if (business.servesLga(neighbour.id)) return _AreaMatch.nearby;
  }
  return _AreaMatch.none;
}

void _sort(List<_Scored> hits, SortOption sort) {
  switch (sort) {
    case SortOption.bestMatch:
      hits.sort((a, b) => b.score.compareTo(a.score));
    case SortOption.fastestResponse:
      hits.sort((a, b) {
        final aTime = a.business.medianResponseMinutes <= 0
            ? 10000
            : a.business.medianResponseMinutes;
        final bTime = b.business.medianResponseMinutes <= 0
            ? 10000
            : b.business.medianResponseMinutes;
        return aTime.compareTo(bTime);
      });
    case SortOption.highestRated:
      hits.sort((a, b) {
        final byRating = b.business.rating.compareTo(a.business.rating);
        if (byRating != 0) return byRating;
        return b.business.reviewCount.compareTo(a.business.reviewCount);
      });
    case SortOption.newest:
      hits.sort(
        (a, b) => b.business.createdAt.compareTo(a.business.createdAt),
      );
  }
}

class _Scored {
  _Scored(this.business, this.score, this.isNearby);

  final Business business;
  final double score;
  final bool isNearby;
}
