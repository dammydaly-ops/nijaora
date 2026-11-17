import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/network_photo.dart';
import '../../../core/widgets/trust_badges.dart';
import '../../../data/models/business.dart';
import '../../../data/models/listing.dart';
import '../../../data/repositories/providers.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({
    super.key,
    required this.businessId,
    required this.listingId,
  });

  final String businessId;
  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(businessProvider(businessId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product'),
        actions: [
          IconButton(
            tooltip: 'View seller',
            onPressed: () => context.push('/business/$businessId'),
            icon: const Icon(Icons.storefront_outlined),
          ),
        ],
      ),
      body: businessAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          title: 'Product unavailable',
          onRetry: () => ref.invalidate(businessProvider(businessId)),
        ),
        data: (business) {
          final listing = _listingFor(business, listingId);
          if (business == null || listing == null) {
            return const Center(child: Text('This product is no longer listed.'));
          }
          return _ProductView(business: business, listing: listing);
        },
      ),
    );
  }

  Listing? _listingFor(Business? business, String id) {
    if (business == null) return null;
    for (final listing in business.listings) {
      if (listing.id == id) return listing;
    }
    return null;
  }
}

class _ProductView extends ConsumerStatefulWidget {
  const _ProductView({required this.business, required this.listing});

  final Business business;
  final Listing listing;

  @override
  ConsumerState<_ProductView> createState() => _ProductViewState();
}

class _ProductViewState extends ConsumerState<_ProductView> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final business = widget.business;
    final listing = widget.listing;
    final images = listing.images.isEmpty ? [null] : listing.images;
    final categoryName = _categoryName();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: AspectRatio(
            aspectRatio: 1.08,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (index) => setState(() => _page = index),
                  itemBuilder: (context, index) => NetworkPhoto(
                    url: images[index],
                    fallbackIcon: Icons.shopping_bag_outlined,
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    bottom: AppSpacing.md,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < images.length; i++)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _page
                                  ? context.palette.cream
                                  : context.palette.cream.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (categoryName != null)
                    Text(
                      categoryName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.palette.amberDeep,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    listing.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              _priceLabel(listing),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.palette.green,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _SellerCard(business: business),
        const SizedBox(height: AppSpacing.lg),
        Text('About this product', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          listing.description.isEmpty
              ? 'Ask the seller for more details, sizes and delivery options.'
              : listing.description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (listing.isAvailable)
          FilledButton.icon(
            onPressed: () => _chat(context),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: Text(listing.actionLabel),
          )
        else
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.palette.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Text(
              'This item is currently unavailable. Ask the seller when it '
              'will be back.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (business.whatsappNumber != null) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _whatsapp,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('WhatsApp seller'),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.push('/business/${business.id}'),
          icon: const Icon(Icons.storefront_outlined),
          label: const Text('View business profile'),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Nijaora does not take payments. Agree the price, size and delivery '
          'directly with the seller.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
              ),
        ),
      ],
    );
  }

  String? _categoryName() {
    final categories = ref.watch(categoriesProvider).value;
    if (categories == null || widget.listing.categoryId == null) return null;
    for (final category in categories) {
      if (category.id == widget.listing.categoryId) return category.name;
    }
    return null;
  }

  String _priceLabel(Listing listing) {
    return switch (listing.priceType) {
      PriceType.fixed => listing.price == null
          ? 'Price on request'
          : formatNaira(listing.price!),
      PriceType.from => listing.price == null
          ? 'Price on request'
          : formatNairaFrom(listing.price!),
      PriceType.negotiable => listing.price == null
          ? 'Negotiable'
          : '${formatNaira(listing.price!)} · negotiable',
      PriceType.onRequest => 'Price on request',
    };
  }

  Future<void> _chat(BuildContext context) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      await _showSignIn(context);
      return;
    }
    try {
      final conversation =
          await ref.read(chatRepositoryProvider).startConversation(
                businessId: widget.business.id,
                listingId: widget.listing.id,
                listingTitle: widget.listing.title,
                firstMessage:
                    'Hello ${widget.business.name}, I am interested in '
                    '"${widget.listing.title}". Is it available?',
              );
      if (!context.mounted) return;
      context.push('/chat/${conversation.id}');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start the chat. Try again.')),
      );
    }
  }

  Future<void> _whatsapp() async {
    final business = widget.business;
    final phone = business.whatsappNumber;
    if (phone == null) return;
    ref.read(analyticsProvider).track('whatsapp_tapped', {
      'businessId': business.id,
      'source': 'product',
    });
    final opened = await ref.read(whatsAppServiceProvider).open(
          phone: phone,
          message: 'Hello ${business.name}, I found you on Nijaora. '
              'I am interested in "${widget.listing.title}". Is it available?',
        );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp on this device.'),
        ),
      );
    }
  }

  Future<void> _showSignIn(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign in to chat'),
        content: const Text(
          'Nijaora chats are tied to your phone number so both sides stay '
          'accountable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/welcome');
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: () => context.push('/business/${business.id}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.palette.border),
          ),
          child: Row(
            children: [
              ClipOval(
                child: NetworkPhoto(
                  url: business.ownerPhotoUrl,
                  width: 48,
                  height: 48,
                  fallbackIcon: Icons.person_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.ownerName ?? business.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${business.name} · ${business.baseArea}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (business.reviewCount > 0) ...[
                      const SizedBox(height: 4),
                      RatingStars(
                        rating: business.rating,
                        reviewCount: business.reviewCount,
                        size: 11,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.palette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
