import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/network_photo.dart';
import '../../../core/widgets/trust_badges.dart';
import '../../../data/models/business.dart';

class BusinessCard extends StatelessWidget {
  const BusinessCard({
    super.key,
    required this.business,
    required this.categoryName,
    required this.areaLabel,
    required this.onTap,
    this.isNearby = false,
  });

  final Business business;
  final String categoryName;
  final String areaLabel;
  final VoidCallback onTap;
  final bool isNearby;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.palette.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetworkPhoto(
                url: business.photos.isEmpty ? null : business.photos.first,
                width: 92,
                height: 108,
                borderRadius: BorderRadius.circular(14),
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
                            business.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (business.isAdminVerified)
                          Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Tooltip(
                              message: 'Location confirmed by Nijaora',
                              child: Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: context.palette.green,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      categoryName,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: context.palette.amberDeep),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      areaLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        RatingStars(
                          rating: business.rating,
                          reviewCount: business.reviewCount,
                          size: 13,
                        ),
                        const Spacer(),
                        if (isNearby)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.palette.amberWash,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              'Nearby',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: context.palette.amberDeep,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AvailabilityPill(
                          availability: business.availability,
                          compact: true,
                        ),
                        LightBandChip(
                          band: business.lightBand,
                          compact: true,
                        ),
                        if (business.medianResponseMinutes > 0)
                          Text(
                            formatResponseTime(
                              business.medianResponseMinutes,
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 10.5),
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
}
