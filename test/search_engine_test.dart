import 'package:flutter_test/flutter_test.dart';
import 'package:nijagig/data/demo/demo_catalog.dart';
import 'package:nijagig/data/models/business.dart';
import 'package:nijagig/data/models/location_node.dart';
import 'package:nijagig/data/models/search.dart';
import 'package:nijagig/data/repositories/demo/demo_location_repository.dart';
import 'package:nijagig/data/search/search_engine.dart';

void main() {
  final catalog = DemoCatalog.instance;
  final locations = DemoLocationRepository(catalog);

  SearchPage search({
    String keyword = '',
    required AreaScope area,
    SortOption sort = SortOption.bestMatch,
    bool includeNearby = false,
  }) {
    return searchBusinesses(
      query: SearchQuery(
        keyword: keyword,
        area: area,
        sort: sort,
        includeNearby: includeNearby,
      ),
      businesses: catalog.businesses,
      categories: catalog.categories,
      locations: locations,
      pageSize: 50,
    );
  }

  group('area matching', () {
    test('a fixed-location business only serves its own LGA', () {
      final radiance = catalog.businessById('radiance-tailors')!;

      expect(radiance.servesLga('ng-la-ikeja'), isTrue);
      expect(radiance.servesLga('ng-la-surulere'), isFalse);
    });

    test('a mobile business serves its listed LGAs and nothing else', () {
      final flowfix = catalog.businessById('flowfix-plumbing')!;

      expect(flowfix.servesLga('ng-la-ikeja'), isTrue);
      expect(flowfix.servesLga('ng-la-mushin'), isTrue);
      expect(flowfix.servesLga('ng-la-eti-osa'), isFalse);
    });

    test('LGA search only returns businesses that serve that LGA', () {
      final page = search(
        keyword: 'plumbing',
        area: const AreaScope(stateId: 'ng-la', lgaId: 'ng-la-ikeja'),
      );

      expect(page.hits, isNotEmpty);
      for (final hit in page.hits.where((hit) => !hit.isNearby)) {
        expect(hit.business.servesLga('ng-la-ikeja'), isTrue);
      }
    });

    test('whole-state search stays inside the state', () {
      final page = search(area: const AreaScope(stateId: 'ng-la'));

      expect(page.hits, isNotEmpty);
      expect(
        page.hits.map((hit) => hit.business.stateId).toSet(),
        {'ng-la'},
      );
    });

    test('an LGA with no exact match falls back to curated neighbours', () {
      final page = search(
        keyword: 'tailoring',
        area: const AreaScope(stateId: 'ng-la', lgaId: 'ng-la-agege'),
      );

      expect(page.totalExact, 0);
      expect(page.totalNearby, greaterThan(0));
      expect(page.hits, isNotEmpty);
      expect(page.hits.every((hit) => hit.isNearby), isTrue);
      expect(
        page.hits.map((hit) => hit.business.id),
        contains('radiance-tailors'),
      );
    });

    test('nearby results stay hidden when exact matches are plentiful', () {
      final page = search(
        area: const AreaScope(stateId: 'ng-la', lgaId: 'ng-la-ikeja'),
      );

      expect(page.totalExact, greaterThanOrEqualTo(3));
      expect(page.hits.where((hit) => hit.isNearby), isEmpty);
    });
  });

  group('ranking', () {
    test('a neighbourhood match adds a small deterministic boost', () {
      final radiance = catalog.businessById('radiance-tailors')!;
      final base = businessScore(
        business: radiance,
        relevance: 0.5,
        areaScore: 0.5,
        neighbourhoodMatch: false,
      );
      final boosted = businessScore(
        business: radiance,
        relevance: 0.5,
        areaScore: 0.5,
        neighbourhoodMatch: true,
      );

      expect(boosted - base, closeTo(0.02, 1e-9));
      expect(boosted, lessThanOrEqualTo(1));
    });

    test('relevance and area carry the documented weights', () {
      final flowfix = catalog.businessById('flowfix-plumbing')!;

      final score = businessScore(
        business: flowfix,
        relevance: 1,
        areaScore: 1,
        neighbourhoodMatch: false,
      );

      final response = 1 - (flowfix.medianResponseMinutes / 240);
      final rating = (flowfix.rating / 5) * 1.0;
      final expected = 0.40 +
          0.20 +
          0.15 * flowfix.completeness +
          0.15 * response +
          0.10 * rating;

      expect(score, closeTo(expected, 1e-9));
    });

    test('reviews below five do not lift the rating component', () {
      Business sample({required int reviewCount}) => Business(
            id: 'sample',
            ownerId: 'owner',
            name: 'Sample Tailors',
            description: '',
            categoryIds: const ['tailoring'],
            stateId: 'ng-la',
            lgaId: 'ng-la-ikeja',
            baseArea: 'Ikeja',
            operatingModel: OperatingModel.fixedLocation,
            serviceAreaLgaIds: const [],
            availability: Availability.availableToday,
            verificationLevel: 1,
            lightScore: 50,
            completeness: 0,
            medianResponseMinutes: 0,
            rating: 5,
            reviewCount: reviewCount,
            photos: const [],
            listings: const [],
            hasProduct: false,
            hasService: true,
            isPublished: true,
            createdAt: DateTime(2026, 1, 1),
          );

      double scoreFor(int reviewCount) => businessScore(
            business: sample(reviewCount: reviewCount),
            relevance: 0,
            areaScore: 0,
            neighbourhoodMatch: false,
          );

      expect(scoreFor(4), 0);
      expect(scoreFor(5), closeTo(0.10 * (5 / 5) * (5 / 20), 1e-9));
    });

    test('result order is stable across identical searches', () {
      SearchPage run() => search(
            keyword: 'plumbing',
            area: const AreaScope(stateId: 'ng-la'),
          );

      final first = run().hits.map((hit) => hit.business.id).toList();
      final second = run().hits.map((hit) => hit.business.id).toList();

      expect(first, second);
    });

    test('highest-rated sort is monotonic', () {
      final page = search(
        area: const AreaScope(stateId: 'ng-la'),
        sort: SortOption.highestRated,
      );

      final ratings = page.hits.map((hit) => hit.business.rating).toList();
      for (var i = 0; i < ratings.length - 1; i++) {
        expect(ratings[i], greaterThanOrEqualTo(ratings[i + 1]));
      }
    });

    test('fastest-response sort is monotonic', () {
      final page = search(
        area: const AreaScope(stateId: 'ng-la'),
        sort: SortOption.fastestResponse,
      );

      final responses = page.hits
          .map((hit) => hit.business.medianResponseMinutes)
          .toList();
      for (var i = 0; i < responses.length - 1; i++) {
        expect(responses[i], lessThanOrEqualTo(responses[i + 1]));
      }
    });
  });
}
