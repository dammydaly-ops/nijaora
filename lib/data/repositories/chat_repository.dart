import '../models/conversation.dart';

abstract class ChatRepository {
  Stream<List<Conversation>> watchConversations(
    String userId, {
    required bool asBusiness,
  });

  Stream<List<Message>> watchMessages(String conversationId);

  Future<Conversation> startConversation({
    required String businessId,
    String? listingId,
    String? firstMessage,
    String? listingTitle,
  });

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    required bool fromBusiness,
  });

  Future<void> markRead({
    required String conversationId,
    required bool asBusiness,
  });
}
