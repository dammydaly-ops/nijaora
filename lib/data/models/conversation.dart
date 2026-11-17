enum MessageKind { text, image }

enum MessageStatus { sending, sent, failed }

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.isFromBusiness = false,
    this.kind = MessageKind.text,
    this.status = MessageStatus.sent,
    this.imageUrl,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final bool isFromBusiness;
  final MessageKind kind;
  final MessageStatus status;
  final String? imageUrl;

  Message copyWith({MessageStatus? status}) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      text: text,
      sentAt: sentAt,
      isFromBusiness: isFromBusiness,
      kind: kind,
      status: status ?? this.status,
      imageUrl: imageUrl,
    );
  }
}

class Conversation {
  const Conversation({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.lastMessage,
    required this.lastMessageAt,
    this.listingId,
    this.unreadForCustomer = 0,
    this.unreadForBusiness = 0,
    this.blockedByCustomer = false,
    this.blockedByBusiness = false,
  });

  final String id;
  final String businessId;
  final String customerId;
  final String? listingId;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadForCustomer;
  final int unreadForBusiness;
  final bool blockedByCustomer;
  final bool blockedByBusiness;

  bool get isBlocked => blockedByCustomer || blockedByBusiness;

  int unreadFor({required bool isBusiness}) =>
      isBusiness ? unreadForBusiness : unreadForCustomer;

  Conversation copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadForCustomer,
    int? unreadForBusiness,
    bool? blockedByCustomer,
    bool? blockedByBusiness,
  }) {
    return Conversation(
      id: id,
      businessId: businessId,
      customerId: customerId,
      listingId: listingId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadForCustomer: unreadForCustomer ?? this.unreadForCustomer,
      unreadForBusiness: unreadForBusiness ?? this.unreadForBusiness,
      blockedByCustomer: blockedByCustomer ?? this.blockedByCustomer,
      blockedByBusiness: blockedByBusiness ?? this.blockedByBusiness,
    );
  }
}
