import 'dart:async';

import '../../demo/demo_catalog.dart';
import '../../models/conversation.dart';
import '../chat_repository.dart';

const _demoCustomerId = 'demo-customer';

class DemoChatRepository implements ChatRepository {
  DemoChatRepository(this._catalog);

  final DemoCatalog _catalog;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<Conversation>> watchConversations(
    String userId, {
    required bool asBusiness,
  }) async* {
    yield _conversations(userId, asBusiness);
    yield* _changes.stream
        .map((_) => _conversations(userId, asBusiness));
  }

  List<Conversation> _conversations(String userId, bool asBusiness) {
    // A demo business account sees every seeded thread; in production the
    // query is scoped to conversations for the owner's business.
    final list = asBusiness
        ? _catalog.conversations
        : _catalog.conversations
            .where((conversation) => conversation.customerId == userId)
            .toList();
    final sorted = List<Conversation>.of(list);
    sorted.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return sorted;
  }

  @override
  Stream<List<Message>> watchMessages(String conversationId) async* {
    yield _messages(conversationId);
    yield* _changes.stream.map((_) => _messages(conversationId));
  }

  List<Message> _messages(String conversationId) {
    final list = _catalog.messages
        .where((message) => message.conversationId == conversationId)
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return list;
  }

  @override
  Future<Conversation> startConversation({
    required String businessId,
    String? listingId,
    String? firstMessage,
    String? listingTitle,
  }) async {
    Conversation? existing;
    for (final conversation in _catalog.conversations) {
      if (conversation.businessId == businessId &&
          conversation.customerId == _demoCustomerId) {
        existing = conversation;
        break;
      }
    }

    if (existing != null) {
      if (firstMessage != null && firstMessage.trim().isNotEmpty) {
        await sendMessage(
          conversationId: existing.id,
          senderId: _demoCustomerId,
          text: firstMessage.trim(),
          fromBusiness: false,
        );
      }
      return existing;
    }

    final now = DateTime.now();
    final conversation = Conversation(
      id: 'conv-${now.microsecondsSinceEpoch}',
      businessId: businessId,
      customerId: _demoCustomerId,
      listingId: listingId,
      lastMessage: firstMessage?.trim().isNotEmpty == true
          ? firstMessage!.trim()
          : 'New conversation',
      lastMessageAt: now,
    );
    _catalog.conversations.add(conversation);

    if (firstMessage != null && firstMessage.trim().isNotEmpty) {
      _catalog.messages.add(Message(
        id: 'msg-${now.microsecondsSinceEpoch}',
        conversationId: conversation.id,
        senderId: _demoCustomerId,
        text: firstMessage.trim(),
        sentAt: now,
      ));
      _scheduleReply(conversation.id, firstMessage);
    }

    _changes.add(null);
    return conversation;
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    required bool fromBusiness,
  }) async {
    final now = DateTime.now();
    final message = Message(
      id: 'msg-${now.microsecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: senderId,
      text: text.trim(),
      sentAt: now,
      isFromBusiness: fromBusiness,
      status: MessageStatus.sending,
    );
    _catalog.messages.add(message);
    final conversationIndex = _catalog.conversations
        .indexWhere((conversation) => conversation.id == conversationId);
    var unreadForBusiness = 0;
    var unreadForCustomer = 0;
    if (conversationIndex >= 0) {
      final conversation = _catalog.conversations[conversationIndex];
      unreadForBusiness =
          fromBusiness ? 0 : conversation.unreadForBusiness + 1;
      unreadForCustomer =
          fromBusiness ? conversation.unreadForCustomer + 1 : 0;
    }
    _touchConversation(
      conversationId,
      lastMessage: text.trim(),
      lastMessageAt: now,
      unreadForBusiness: unreadForBusiness,
      unreadForCustomer: unreadForCustomer,
    );
    _changes.add(null);

    await Future<void>.delayed(const Duration(milliseconds: 320));
    final index =
        _catalog.messages.indexWhere((item) => item.id == message.id);
    if (index >= 0) {
      _catalog.messages[index] =
          _catalog.messages[index].copyWith(status: MessageStatus.sent);
      _changes.add(null);
    }

    if (!fromBusiness) {
      _scheduleReply(conversationId, text);
    }
  }

  void _scheduleReply(String conversationId, String customerMessage) {
    Timer(const Duration(milliseconds: 1600), () {
      final reply = _replyFor(customerMessage);
      final now = DateTime.now();
      _catalog.messages.add(Message(
        id: 'msg-${now.microsecondsSinceEpoch}',
        conversationId: conversationId,
        senderId: 'business',
        text: reply,
        sentAt: now,
        isFromBusiness: true,
      ));
      final conversationIndex = _catalog.conversations
          .indexWhere((item) => item.id == conversationId);
      final unread = conversationIndex >= 0
          ? _catalog.conversations[conversationIndex].unreadForCustomer
          : 0;
      _touchConversation(
        conversationId,
        lastMessage: reply,
        lastMessageAt: now,
        unreadForCustomer: unread + 1,
      );
      _changes.add(null);
    });
  }

  String _replyFor(String message) {
    final text = message.toLowerCase();
    if (text.contains('price') ||
        text.contains('cost') ||
        text.contains('how much')) {
      return 'Prices depend on the job. Send a photo or more details and I '
          'will give you a firm quote.';
    }
    if (text.contains('today') || text.contains('urgent')) {
      return 'I can come today. What time works for you?';
    }
    if (text.contains('photo')) {
      return 'Got it. Please send the photo and I will take a look.';
    }
    return 'Thanks for your message. I will get back to you shortly with '
        'details.';
  }

  @override
  Future<void> markRead({
    required String conversationId,
    required bool asBusiness,
  }) async {
    _touchConversation(
      conversationId,
      unreadForBusiness: asBusiness ? 0 : null,
      unreadForCustomer: asBusiness ? null : 0,
    );
    _changes.add(null);
  }

  void _touchConversation(
    String conversationId, {
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadForBusiness,
    int? unreadForCustomer,
  }) {
    final index = _catalog.conversations
        .indexWhere((conversation) => conversation.id == conversationId);
    if (index < 0) return;
    final conversation = _catalog.conversations[index];
    _catalog.conversations[index] = conversation.copyWith(
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      unreadForBusiness: unreadForBusiness,
      unreadForCustomer: unreadForCustomer,
    );
  }
}
