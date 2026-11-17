import 'business.dart';
import 'category.dart';
import 'listing.dart';

/// A ready-made product listing joined to its seller and product category.
class ProductItem {
  const ProductItem({
    required this.listing,
    required this.business,
    this.category,
  });

  final Listing listing;
  final Business business;
  final Category? category;

  String get id => listing.id;
  String get title => listing.title;
  String get description => listing.description;
  List<String> get images => listing.images;
  int? get price => listing.price;
  PriceType get priceType => listing.priceType;
  String get sellerName => business.ownerName ?? business.name;
  String? get sellerPhotoUrl => business.ownerPhotoUrl;
  String get businessName => business.name;
  String get areaLabel => business.baseArea;
  double get rating => business.rating;
  int get reviewCount => business.reviewCount;
}
