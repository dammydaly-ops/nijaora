enum ListingType {
  product,
  service;

  String get label => switch (this) {
        ListingType.product => 'Product',
        ListingType.service => 'Service',
      };
}

enum PriceType {
  fixed,
  from,
  negotiable,
  onRequest;

  String get label => switch (this) {
        PriceType.fixed => 'Fixed price',
        PriceType.from => 'From price',
        PriceType.negotiable => 'Negotiable',
        PriceType.onRequest => 'Price on request',
      };
}

class Listing {
  const Listing({
    required this.id,
    required this.businessId,
    required this.type,
    required this.title,
    required this.description,
    required this.priceType,
    required this.images,
    this.price,
    this.isAvailable = true,
    this.categoryId,
  });

  final String id;
  final String businessId;
  final ListingType type;
  final String title;
  final String description;
  final PriceType priceType;
  final int? price;
  final List<String> images;
  final bool isAvailable;
  final String? categoryId;

  String get actionLabel => switch (type) {
        ListingType.product => 'Ask about this item',
        ListingType.service => 'Request a quote',
      };
}
