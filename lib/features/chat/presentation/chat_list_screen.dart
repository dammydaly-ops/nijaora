import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/time_labels.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/network_photo.dart';
import '../../../core/widgets/trust_badges.dart';
import '../../../data/models/conversation.dart';
import '../../../data/repositories/providers.dart';
import '../../auth/guest_mode.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final conversations = ref.watch(conversationsProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chats')),
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Sign in to see your chats',
          message:
              'Conversations are private between you and the business. Sign '
              'in with your phone number to continue.',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Center(
              child: Text(
                user.isBusiness ? 'Business inbox' : 'Your enquiries',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: conversations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: 'We could not load your chats.',
          onRetry: () => ref.invalidate(conversationsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.forum_outlined,
              title: 'No conversations yet',
              message:
                  'Start a chat from a business profile. Only you and the '
                  'business can read it.',
              actions: [
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Discover businesses'),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 2),
            itemBuilder: (context, index) => _ConversationTile(
              conversation: items[index],
              isBusiness: user.isBusiness,
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.conversation,
    required this.isBusiness,
  });

  final Conversation conversation;
  final bool isBusiness;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(businessProvider(conversation.businessId));
    final business = businessAsync.value;
    final unread = conversation.unreadFor(isBusiness: isBusiness);

    return InkWell(
      onTap: business == null
          ? null
          : () => context.push('/chat/${conversation.id}'),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            NetworkPhoto(
              url: business?.photos.isEmpty == false
                  ? business!.photos.first
                  : null,
              width: 54,
              height: 54,
              borderRadius: BorderRadius.circular(16),
              fallbackIcon: Icons.storefront_rounded,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          business?.name ?? 'Business',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        timeAgo(conversation.lastMessageAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.palette.amberDeep,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 18),
                          alignment: Alignment.center,
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (business != null && business.isAdminVerified) ...[
                    const SizedBox(height: 4),
                    VerifiedBadge(level: business.verificationLevel, compact: true),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
