import '../models/business.dart';
import '../models/business_draft.dart';
import '../models/category.dart';
import '../models/location_node.dart';
import '../models/review.dart';
import '../models/search.dart';

abstract class BusinessRepository {
  Future<SearchPage> search(
    SearchQuery query, {
    int page = 0,
    int pageSize = 20,
  });

  Future<Business?> byId(String id);

  Future<List<Business>> featured(AreaScope? area, {int limit = 5});

  Future<List<Business>> allPublished();

  Future<List<Review>> reviewsFor(String businessId);

  Future<List<Category>> categories();

  Future<Business> publish(BusinessDraft draft, {required String ownerId});
}
