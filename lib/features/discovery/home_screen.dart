import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_palette.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/nija_logo.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/skeletons.dart';
import '../../data/models/category.dart';
import '../../data/reference/catalog_taxonomy.dart';
import '../../data/repositories/providers.dart';
import '../auth/guest_mode.dart';
import '../discovery/category_visuals.dart';
import '../discovery/home_hero.dart';
import '../discovery/search_providers.dart';
import '../discovery/widgets/business_card.dart';
import '../location/area_labels.dart';
import '../location/area_picker_sheet.dart';
import '../location/area_selection.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationRepositoryProvider);
    final area = ref.watch(selectedAreaProvider);
    final user = ref.watch(currentUserProvider);
    final isGuest = ref.watch(guestModeProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final featuredAsync = ref.watch(featuredBusinessesProvider);
    final categories = categoriesAsync.value ?? const <Category>[];
    final serviceCategories = serviceParents(categories);
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };
    final areaName = area == null
        ? 'Nigeria'
        : areaInlineLabel(area, locations);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth > 1212
        ? (screenWidth - 1180) / 2
        : AppSpacing.lg;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: context.palette.ink,
          onRefresh: () async {
            ref.invalidate(featuredBusinessesProvider);
            try {
              await ref.read(featuredBusinessesProvider.future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.md,
              horizontalPadding,
              AppSpacing.xxl,
            ),
            children: [
              Row(
                children: [
                  const Expanded(child: NijaLogo(size: 36, showTagline: true)),
                  _AccountButton(userName: user?.displayName),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const HomeHero(),
              if (isGuest) ...[
                const SizedBox(height: AppSpacing.md),
                _GuestBanner(
                  onSignIn: () {
                    ref.read(guestModeProvider.notifier).disable();
                    context.go('/welcome');
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'What do you need?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (serviceCategories.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${serviceCategories.length} categories',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (categoriesAsync.isLoading && categories.isEmpty)
                const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: serviceCategories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 1.12,
                  ),
                  itemBuilder: (context, index) {
                    final category = serviceCategories[index];
                    return _CategoryTile(
                      category: category,
                      onTap: () {
                        ref
                            .read(searchQueryProvider.notifier)
                            .setCategory(category.id);
                        context.push('/search');
                      },
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(
                title: area == null ? 'Popular on Nijaora' : 'Shining near you',
                subtitle: area == null
                    ? 'Trusted businesses across Nigeria'
                    : 'In $areaName',
                actionLabel: 'See all',
                onAction: () {
                  ref.read(searchQueryProvider.notifier).setCategory(null);
                  context.push('/search');
                },
              ),
              const SizedBox(height: AppSpacing.md),
              featuredAsync.when(
                loading: () => Column(
                  children: const [
                    BusinessCardSkeleton(),
                    SizedBox(height: AppSpacing.md),
                    BusinessCardSkeleton(),
                    SizedBox(height: AppSpacing.md),
                    BusinessCardSkeleton(),
                  ],
                ),
                error: (error, _) => _InlineError(
                  message:
                      'We could not load businesses right now. Check your '
                      'connection.',
                  onRetry: () => ref.invalidate(featuredBusinessesProvider),
                ),
                data: (businesses) {
                  if (businesses.isEmpty) {
                    return _NoBusinesses(
                      areaName: areaName,
                      onChooseArea: () => showAreaPicker(context),
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < businesses.length; i++) ...[
                        BusinessCard(
                          business: businesses[i],
                          categoryName:
                              categoryNames[businesses[i].primaryCategoryId] ??
                              'Business',
                          areaLabel: businessAreaLabel(
                            businesses[i],
                            locations,
                          ),
                          onTap: () =>
                              context.push('/business/${businesses[i].id}'),
                        ),
                        if (i != businesses.length - 1)
                          const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              const _TrustStrip(),
              const SizedBox(height: AppSpacing.xl),
              _BusinessCta(
                signedIn: user != null,
                onTap: () {
                  if (user == null) {
                    ref.read(guestModeProvider.notifier).disable();
                    context.go('/welcome');
                  } else {
                    context.push('/registration');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    final initial = (userName == null || userName!.isEmpty)
        ? null
        : userName!.trim().characters.first.toUpperCase();

    return GestureDetector(
      onTap: () => context.go('/account'),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: context.palette.surface,
          shape: BoxShape.circle,
          border: Border.all(color: context.palette.border),
        ),
        alignment: Alignment.center,
        child: initial == null
            ? const Icon(Icons.person_outline_rounded, size: 22)
            : Text(
                initial,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.palette.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.palette.amberWash,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  categoryIcon(category.id),
                  size: 19,
                  color: context.palette.amberDeep,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestBanner extends StatelessWidget {
  const _GuestBanner({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.palette.amberWash,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: context.palette.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_rounded, size: 17),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Browsing as guest. Sign in to chat or review.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.palette.ink),
            ),
          ),
          TextButton(onPressed: onSignIn, child: const Text('Sign in')),
        ],
      ),
    );
  }
}

class _NoBusinesses extends StatelessWidget {
  const _NoBusinesses({required this.areaName, required this.onChooseArea});

  final String areaName;
  final VoidCallback onChooseArea;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.palette.border),
      ),
      child: EmptyState(
        icon: Icons.storefront_rounded,
        title: 'No businesses in $areaName yet',
        message:
            'We are onboarding artisans and shops area by area. Try a nearby '
            'LGA or check back soon.',
        actions: [
          OutlinedButton(
            onPressed: onChooseArea,
            child: const Text('Choose another area'),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: context.palette.muted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.location_off_rounded, 'No GPS'),
      (Icons.forum_rounded, 'Real chats'),
      (Icons.verified_rounded, 'Verified reviews'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: Column(
                children: [
                  Icon(item.$1, size: 19, color: context.palette.inkSoft),
                  const SizedBox(height: 6),
                  Text(
                    item.$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BusinessCta extends StatelessWidget {
  const _BusinessCta({required this.signedIn, required this.onTap});

  final bool signedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.ink,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Own a business?',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: context.palette.cream),
                ),
                const SizedBox(height: 2),
                Text(
                  signedIn
                      ? 'Publish in under five minutes.'
                      : 'Sign in, then publish your profile.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.palette.cream.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.amber,
              foregroundColor: context.palette.ink,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Get listed'),
          ),
        ],
      ),
    );
  }
}
