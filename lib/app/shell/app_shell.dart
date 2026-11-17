import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_palette.dart';
import '../../data/repositories/providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = location.startsWith('/products')
        ? 1
        : location.startsWith('/chats')
            ? 2
            : location.startsWith('/account')
                ? 3
                : 0;

    final user = ref.watch(currentUserProvider);
    final conversations = ref.watch(conversationsProvider).value ?? const [];
    final unread = user == null
        ? 0
        : conversations.fold<int>(
            0,
            (total, conversation) =>
                total + conversation.unreadFor(isBusiness: user.isBusiness),
          );

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (selected) {
          switch (selected) {
            case 0:
              context.go('/');
            case 1:
              context.go('/products');
            case 2:
              context.go('/chats');
            case 3:
              context.go('/account');
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Discover',
          ),
          const NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag_rounded),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              backgroundColor: context.palette.amberDeep,
              child: const Icon(Icons.forum_outlined),
            ),
            selectedIcon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              backgroundColor: context.palette.amberDeep,
              child: const Icon(Icons.forum_rounded),
            ),
            label: 'Chats',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
