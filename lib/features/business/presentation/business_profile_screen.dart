import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_labels.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/network_photo.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/trust_badges.dart';
import '../../../data/models/business.dart';
import '../../../data/models/listing.dart';
import '../../../data/models/review.dart';
import '../../../data/repositories/providers.dart';
import '../../auth/guest_mode.dart';
import '../../location/area_labels.dart';

class BusinessProfileScreen extends ConsumerWidget {
  const BusinessProfileScreen({super.key, required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(businessProvider(businessId));

    return businessAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: ErrorView(
          message: 'We could not load this business.',
          onRetry: () => ref.invalidate(businessProvider(businessId)),
        ),
      ),
      data: (business) {
        if (business == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
            ),
            body: const EmptyState(
              icon: Icons.storefront_rounded,
              title: 'Business not found',
              message: 'This profile may have been removed or unpublished.',
            ),
          );
        }
        return _ProfileView(business: business);
      },
    );
  }
}

class _ProfileView extends ConsumerWidget {
  const _ProfileView({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationRepositoryProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final reviewsAsync = ref.watch(businessReviewsProvider(business.id));

    String? categoryName;
    for (final category in categories) {
      if (category.id == business.primaryCategoryId) {
        categoryName = category.name;
        break;
      }
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 250,
            backgroundColor: context.palette.cream,
            surfaceTintColor: Colors.transparent,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _RoundIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.pop(),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _RoundIconButton(
                  icon: Icons.ios_share_rounded,
                  onTap: () => _share(context, ref),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkPhoto(
                    url: business.photos.isEmpty ? null : business.photos.first,
                    fallbackIcon: Icons.storefront_rounded,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC15171C)],
                        stops: [0.55, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    bottom: AppSpacing.lg,
                    child: Row(
                      children: [
                        VerifiedBadge(level: business.verificationLevel),
                        const SizedBox(width: AppSpacing.sm),
                        AvailabilityPill(availability: business.availability),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    categoryName ?? 'Business',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.palette.amberDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: context.palette.muted,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          businessAreaLabel(business, locations),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  if (business.address?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 14,
                          color: context.palette.muted,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            business.address!.trim(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      RatingStars(
                        rating: business.rating,
                        reviewCount: business.reviewCount,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Ã‚Â· ${business.reviewCount} verified reviews',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _TrustPanel(business: business),
                  if (business.ownerName != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _OwnerCard(business: business),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _startChat(context, ref, business),
                          icon: const Icon(Icons.forum_rounded, size: 18),
                          label: const Text('Chat in app'),
                        ),
                      ),
                      if (business.whatsappNumber != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openWhatsApp(context, ref),
                            icon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('WhatsApp'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  const SectionHeader(title: 'About'),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    business.description,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(height: 1.55),
                  ),
                  if (business.openingHours != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 15,
                          color: context.palette.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          business.openingHours!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  SectionHeader(
                    title: 'Portfolio',
                    subtitle: '${business.photos.length} photos',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Portfolio(photos: business.photos),
                  const SizedBox(height: AppSpacing.xxl),
                  SectionHeader(
                    title: 'Products & services',
                    subtitle: business.listings.isEmpty
                        ? 'Ask for a custom quote'
                        : '${business.listings.length} listings',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (business.listings.isEmpty)
                    Text(
                      'No listings yet. Start a chat to ask what '
                      '${business.name} can do for you.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    for (final listing in business.listings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ListingTile(
                          listing: listing,
                          onTap: () => _startChat(
                            context,
                            ref,
                            business,
                            listing: listing,
                          ),
                        ),
                      ),
                  const SizedBox(height: AppSpacing.xxl),
                  const SectionHeader(
                    title: 'Reviews',
                    subtitle: 'Only customers who chatted can review',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  reviewsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Text(
                      'Reviews are unavailable right now.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    data: (reviews) =>
                        _Reviews(reviews: reviews, business: business),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _report(context, ref),
                      icon: const Icon(Icons.flag_outlined, size: 16),
                      label: const Text('Report this business'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Nijaora does not take payments. Agree the price and '
                    'delivery directly with the business.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startChat(
    BuildContext context,
    WidgetRef ref,
    Business business, {
    Listing? listing,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      await _showSignIn(context, ref);
      return;
    }
    try {
      final message = listing == null
          ? null
          : 'Hello ${business.name}, I am interested in "${listing.title}". '
                'Is it available?';
      final conversation = await ref
          .read(chatRepositoryProvider)
          .startConversation(
            businessId: business.id,
            listingId: listing?.id,
            listingTitle: listing?.title,
            firstMessage: message,
          );
      ref.read(analyticsProvider).track('chat_started', {
        'businessId': business.id,
        'source': listing == null ? 'profile' : 'listing',
      });
      if (!context.mounted) return;
      context.push('/chat/${conversation.id}');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start the chat. Try again.')),
        );
      }
    }
  }

  Future<void> _openWhatsApp(BuildContext context, WidgetRef ref) async {
    final phone = business.whatsappNumber;
    if (phone == null) return;
    ref.read(analyticsProvider).track('whatsapp_tapped', {
      'businessId': business.id,
      'source': 'profile',
    });
    final opened = await ref
        .read(whatsAppServiceProvider)
        .open(
          phone: phone,
          message:
              'Hello ${business.name}, I found you on Nijaora. '
              'Are you available?',
        );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp on this device.'),
        ),
      );
    }
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final url = 'https://nijaora.com/${business.slug ?? business.id}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Link copied: $url')));
  }

  Future<void> _showSignIn(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign in to chat'),
        content: const Text(
          'Nijaora chats are tied to your phone number so reviews stay real '
          'and both sides stay accountable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(guestModeProvider.notifier).disable();
              context.go('/welcome');
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  void _report(BuildContext context, WidgetRef ref) {
    const reasons = [
      'Fake or misleading profile',
      'Wrong location',
      'Scam or payment request',
      'Abusive content',
      'Something else',
    ];
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'What is wrong with this business?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            for (final reason in reasons)
              ListTile(
                title: Text(reason),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(analyticsProvider).track('report_submitted', {
                    'targetType': 'business',
                    'reason': reason,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Report received. Our team will review it and keep '
                        'you updated.',
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.cream,
      shape: const CircleBorder(),
      elevation: 0.5,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 19, color: context.palette.ink),
        ),
      ),
    );
  }
}

class _TrustPanel extends StatelessWidget {
  const _TrustPanel({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _TrustMetric(
                  label: 'Light score',
                  valueWidget: LightBandChip(band: business.lightBand),
                ),
              ),
              Container(width: 1, height: 34, color: context.palette.border),
              Expanded(
                child: _TrustMetric(
                  label: 'Replies',
                  value: business.medianResponseMinutes > 0
                      ? formatResponseTime(business.medianResponseMinutes)
                      : 'New',
                ),
              ),
              Container(width: 1, height: 34, color: context.palette.border),
              Expanded(
                child: _TrustMetric(
                  label: 'Reviews',
                  value: '${business.reviewCount}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                'Profile complete',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: business.completeness.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: context.palette.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation(context.palette.amber),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${(business.completeness * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.palette.ink,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _showLightScoreInfo(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'How the light score works',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLightScoreInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('The light score'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A trust summary, not a verification badge. Only Nijaora can '
                'mark a business as Verified.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'Starting weights:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6),
              Text(
                'Ã¢â‚¬Â¢ Profile completeness Ã¢â‚¬â€ 25\n'
                'Ã¢â‚¬Â¢ Response speed Ã¢â‚¬â€ 20\n'
                'Ã¢â‚¬Â¢ Verified reviews and rating Ã¢â‚¬â€ 25 (from 5 reviews)\n'
                'Ã¢â‚¬Â¢ Phone verification Ã¢â‚¬â€ 15\n'
                'Ã¢â‚¬Â¢ Admin verification Ã¢â‚¬â€ 15',
              ),
              SizedBox(height: 12),
              Text(
                'Bands: Starting (0Ã¢â‚¬â€œ39), Growing (40Ã¢â‚¬â€œ69), Shining (70Ã¢â‚¬â€œ100). '
                'Small differences do not change the band.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.business});

  final Business business;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: NetworkPhoto(
              url: business.ownerPhotoUrl,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
              fallbackIcon: Icons.person_rounded,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meet the owner',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.palette.amberDeep,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  business.ownerName!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (business.ownerBio != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    business.ownerBio!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (business.isPhoneVerified)
            Icon(
              Icons.verified_user_rounded,
              size: 18,
              color: context.palette.green,
            ),
        ],
      ),
    );
  }
}

class _TrustMetric extends StatelessWidget {
  const _TrustMetric({required this.label, this.value, this.valueWidget});

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        valueWidget ??
            Text(
              value ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
        const SizedBox(height: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontSize: 10.5),
        ),
      ],
    );
  }
}

class _Portfolio extends StatelessWidget {
  const _Portfolio({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Text(
        'No portfolio photos yet.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, index) => GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: InteractiveViewer(
              child: NetworkPhoto(
                url: photos[index],
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        child: NetworkPhoto(
          url: photos[index],
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _ListingTile extends StatelessWidget {
  const _ListingTile({required this.listing, required this.onTap});

  final Listing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.palette.border),
          ),
          child: Row(
            children: [
              NetworkPhoto(
                url: listing.images.isEmpty ? null : listing.images.first,
                width: 68,
                height: 68,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _priceLabel(listing),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.palette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      listing.actionLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.palette.amberDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.palette.muted),
            ],
          ),
        ),
      ),
    );
  }

  String _priceLabel(Listing listing) {
    return switch (listing.priceType) {
      PriceType.fixed =>
        listing.price == null ? 'Ask for price' : formatNaira(listing.price!),
      PriceType.from =>
        listing.price == null ? 'From price' : formatNairaFrom(listing.price!),
      PriceType.negotiable => 'Negotiable',
      PriceType.onRequest => 'Price on request',
    };
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.reviews, required this.business});

  final List<Review> reviews;
  final Business business;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: context.palette.border),
        ),
        child: Text(
          'No reviews yet. A customer can review after a real conversation '
          'with ${business.name}.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Column(
      children: [
        for (final review in reviews)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: context.palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      RatingStars(rating: review.rating.toDouble(), size: 13),
                      const Spacer(),
                      Text(
                        timeAgo(review.createdAt),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        review.customerName,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.verified_rounded,
                        size: 12,
                        color: context.palette.green,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'reviewed after a chat',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.palette.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.text,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(height: 1.45),
                  ),
                  if (review.ownerReply != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: context.palette.amberWash,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reply from the owner',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: context.palette.amberDeep,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            review.ownerReply!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.palette.ink),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
