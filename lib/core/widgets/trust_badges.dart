import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/business.dart';

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, required this.level, this.compact = false});

  final int level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final verified = level >= 2;
    final color = verified ? context.palette.green : context.palette.muted;
    final background = verified ? context.palette.greenWash : context.palette.surfaceAlt;
    final label = verified ? 'Verified' : 'Phone verified';
    final icon = verified ? Icons.verified_rounded : Icons.phone_iphone_rounded;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class LightBandChip extends StatelessWidget {
  const LightBandChip({super.key, required this.band, this.compact = false});

  final LightBand band;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (band) {
      LightBand.shining => context.palette.amberDeep,
      LightBand.growing => context.palette.green,
      LightBand.starting => context.palette.muted,
    };
    final background = switch (band) {
      LightBand.shining => context.palette.amberWash,
      LightBand.growing => context.palette.greenWash,
      LightBand.starting => context.palette.surfaceAlt,
    };

    return Tooltip(
      message: band.explanation,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wb_sunny_rounded, size: compact ? 12 : 14, color: color),
            const SizedBox(width: 4),
            Text(
              band.label,
              style: TextStyle(
                fontSize: compact ? 10.5 : 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AvailabilityPill extends StatelessWidget {
  const AvailabilityPill({
    super.key,
    required this.availability,
    this.compact = false,
  });

  final Availability availability;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (availability) {
      Availability.availableToday => (context.palette.green, context.palette.greenWash),
      Availability.busyThisWeek => (context.palette.amberDeep, context.palette.amberWash),
      Availability.notTakingJobs => (context.palette.red, context.palette.redWash),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        availability.label,
        style: TextStyle(
          fontSize: compact ? 10.5 : 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.reviewCount,
    this.size = 14,
    this.showNumber = true,
  });

  final double rating;
  final int? reviewCount;
  final double size;
  final bool showNumber;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            rating >= i + 0.75
                ? Icons.star_rounded
                : rating >= i + 0.25
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: size,
            color: context.palette.amber,
          ),
        if (showNumber) ...[
          const SizedBox(width: 4),
          Text(
            rating > 0 ? rating.toStringAsFixed(1) : 'New',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.palette.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: size - 1,
                ),
          ),
        ],
        if (reviewCount != null) ...[
          const SizedBox(width: 3),
          Text(
            '($reviewCount)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: size - 1,
                ),
          ),
        ],
      ],
    );
  }
}

class ResponseTimeText extends StatelessWidget {
  const ResponseTimeText({
    super.key,
    required this.minutes,
    this.compact = false,
  });

  final int minutes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = minutes <= 0
        ? 'New Â· no replies yet'
        : 'Replies in ${formatResponseTime(minutes)}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.bolt_rounded,
          size: compact ? 13 : 15,
          color: minutes > 0 ? context.palette.amberDeep : context.palette.muted,
        ),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: compact ? 11 : 12.5,
                  color: context.palette.muted,
                ),
          ),
        ),
      ],
    );
  }
}
