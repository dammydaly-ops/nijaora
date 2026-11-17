import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_labels.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/network_photo.dart';
import '../../../data/models/business.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/listing.dart';
import '../../../data/repositories/providers.dart';
import '../../auth/guest_mode.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.read(chatRepositoryProvider).markRead(
              conversationId: widget.conversationId,
              asBusiness: user.isBusiness,
            );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Conversation? _findConversation(List<Conversation> conversations) {
    for (final conversation in conversations) {
      if (conversation.id == widget.conversationId) return conversation;
    }
    return null;
  }

  Future<void> _send(String senderId, bool fromBusiness) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    _messageController.clear();
    setState(() => _sending = true);
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
            conversationId: widget.conversationId,
            senderId: senderId,
            text: text,
            fromBusiness: fromBusiness,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Sign in to continue',
          message: 'Chats are private between you and the business.',
          actions: [
            FilledButton(
              onPressed: () {
                ref.read(guestModeProvider.notifier).disable();
                context.go('/welcome');
              },
              child: const Text('Sign in'),
            ),
          ],
        ),
      );
    }

    final conversations = ref.watch(conversationsProvider);
    final conversation =
        _findConversation(conversations.value ?? const []);
    final businessAsync = conversation == null
        ? null
        : ref.watch(businessProvider(conversation.businessId));
    final business = businessAsync?.value;
    final messages = ref.watch(messagesProvider(widget.conversationId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(business?.name ?? 'Conversation'),
            if (business != null)
              Text(
                business.medianResponseMinutes > 0
                    ? 'Usually replies in '
                        '${formatResponseTime(business.medianResponseMinutes)}'
                    : 'New on Nijaora',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                    ),
              ),
          ],
        ),
        actions: [
          if (business?.whatsappNumber != null && !user.isBusiness)
            IconButton(
              tooltip: 'Continue on WhatsApp',
              onPressed: () => _openWhatsApp(business!, conversation),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              if (value == 'whatsapp') {
                await _openWhatsApp(business!, conversation);
                return;
              }
              _handleMenu(value);
            },
            itemBuilder: (context) => [
              if (business?.whatsappNumber != null && !user.isBusiness)
                const PopupMenuItem(
                  value: 'whatsapp',
                  child: Text('Continue on WhatsApp'),
                ),
              const PopupMenuItem(
                value: 'report',
                child: Text('Report conversation'),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Text('Block this business'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (business != null && conversation?.listingId != null)
            _ListingContext(
              listing: _listingFor(business, conversation!.listingId!),
            ),
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const Center(
                child: Text('We could not load this conversation.'),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'Say hello and explain what you need. '
                        'Photos help businesses quote faster.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final message = items[items.length - 1 - index];
                    final isMine = user.isBusiness
                        ? message.isFromBusiness
                        : !message.isFromBusiness;
                    return _MessageBubble(message: message, isMine: isMine);
                  },
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              border: Border(top: BorderSide(color: context.palette.border)),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(user.id, user.isBusiness),
                      decoration: const InputDecoration(
                        hintText: 'Write a message...',
                        counterText: '',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.palette.ink,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      tooltip: 'Send',
                      onPressed: _sending
                          ? null
                          : () => _send(user.id, user.isBusiness),
                      icon: Icon(
                        Icons.send_rounded,
                        size: 19,
                        color: context.palette.cream,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Listing? _listingFor(Business business, String listingId) {
    for (final listing in business.listings) {
      if (listing.id == listingId) return listing;
    }
    return null;
  }

  Future<void> _openWhatsApp(
    Business business,
    Conversation? conversation,
  ) async {
    final phone = business.whatsappNumber;
    if (phone == null) return;
    ref.read(analyticsProvider).track('whatsapp_tapped', {
      'businessId': business.id,
      'source': 'chat',
    });

    var message = 'Hello ${business.name}, I found you on Nijaora.';
    final listingId = conversation?.listingId;
    if (listingId != null) {
      final listing = _listingFor(business, listingId);
      if (listing != null) {
        message = 'Hello ${business.name}, I found you on Nijaora. '
            'I am interested in "${listing.title}". Is it available?';
      }
    }

    final opened = await ref.read(whatsAppServiceProvider).open(
          phone: phone,
          message: message,
        );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp on this device.'),
        ),
      );
    }
  }

  void _handleMenu(String value) {
    final isReport = value == 'report';
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isReport ? Icons.flag_outlined : Icons.block_rounded,
              ),
              title: Text(isReport ? 'Report conversation' : 'Block business'),
              subtitle: Text(
                isReport
                    ? 'Our team reviews reports and keeps you updated.'
                    : 'A blocked business cannot send you new messages.',
              ),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isReport
                          ? 'Report received. Our team will review it.'
                          : 'Business blocked. You can unblock later.',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? context.palette.ink : context.palette.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 5),
            bottomRight: Radius.circular(isMine ? 5 : 16),
          ),
          border: isMine ? null : Border.all(color: context.palette.border),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: isMine ? context.palette.cream : context.palette.ink,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  clockTime(message.sentAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMine
                        ? context.palette.cream.withValues(alpha: 0.55)
                        : context.palette.muted,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == MessageStatus.failed
                        ? Icons.error_outline_rounded
                        : message.status == MessageStatus.sending
                            ? Icons.schedule_rounded
                            : Icons.done_all_rounded,
                    size: 12,
                    color: message.status == MessageStatus.failed
                        ? context.palette.red
                        : context.palette.cream.withValues(alpha: 0.65),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingContext extends StatelessWidget {
  const _ListingContext({required this.listing});

  final Listing? listing;

  @override
  Widget build(BuildContext context) {
    if (listing == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          NetworkPhoto(
            url: listing!.images.isEmpty ? null : listing!.images.first,
            width: 42,
            height: 42,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About this item',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: context.palette.amberDeep,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  listing!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (listing!.price != null)
            Text(
              formatNaira(listing!.price!),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
