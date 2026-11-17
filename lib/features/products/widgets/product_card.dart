import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/network_photo.dart';
import '../../../data/models/listing.dart';
import '../../../data/models/product_item.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final ProductItem item;
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.12,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetworkPhoto(
                      url: item.images.isEmpty ? null : item.images.first,
                      fallbackIcon: Icons.shopping_bag_outlined,
                    ),
                    if (item.category != null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.palette.ink.withValues(alpha: 0.78),
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            item.category!.name,
                            style: TextStyle(
                              color: context.palette.cream,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _priceLabel(item),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: context.palette.green,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ClipOval(
                          child: NetworkPhoto(
                            url: item.sellerPhotoUrl,
                            width: 22,
                            height: 22,
                            fallbackIcon: Icons.person_rounded,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: context.palette.muted,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            item.areaLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 10.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _priceLabel(ProductItem item) {
    return switch (item.priceType) {
      PriceType.fixed => item.price == null
          ? 'Price on request'
          : formatNaira(item.price!),
      PriceType.from => item.price == null
          ? 'Price on request'
          : formatNairaFrom(item.price!),
      PriceType.negotiable => item.price == null
          ? 'Negotiable'
          : '${formatNaira(item.price!)} · negotiable',
      PriceType.onRequest => 'Price on request',
    };
  }
}
