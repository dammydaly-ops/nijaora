class Review {
  const Review({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    required this.rating,
    required this.text,
    required this.createdAt,
    this.photoUrl,
    this.ownerReply,
    this.isVerified = true,
  });

  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final int rating;
  final String text;
  final DateTime createdAt;
  final String? photoUrl;
  final String? ownerReply;
  final bool isVerified;
}
