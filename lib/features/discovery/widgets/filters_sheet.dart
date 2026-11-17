import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/business.dart';
import '../../../data/models/listing.dart';
import '../../../data/models/search.dart';

Future<SearchFilters?> showFilterSheet(
  BuildContext context,
  SearchFilters current,
) {
  return showModalBottomSheet<SearchFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FilterSheet(initial: current),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final SearchFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late SearchFilters _filters = widget.initial;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.palette.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Filters',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _filters = const SearchFilters();
                  }),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              children: [
                const _FilterLabel('Listing type'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _Pill(
                      label: 'Any',
                      selected: _filters.listingType == null,
                      onTap: () => setState(() {
                        _filters = _filters.copyWith(clearListingType: true);
                      }),
                    ),
                    _Pill(
                      label: 'Services',
                      selected: _filters.listingType == ListingType.service,
                      onTap: () => setState(() {
                        _filters = _filters.copyWith(
                          listingType: ListingType.service,
                        );
                      }),
                    ),
                    _Pill(
                      label: 'Products',
                      selected: _filters.listingType == ListingType.product,
                      onTap: () => setState(() {
                        _filters = _filters.copyWith(
                          listingType: ListingType.product,
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const _FilterLabel('Availability'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _Pill(
                      label: 'Any',
                      selected: _filters.availability == null,
                      onTap: () => setState(() {
                        _filters = _filters.copyWith(clearAvailability: true);
                      }),
                    ),
                    for (final availability in Availability.values)
                      _Pill(
                        label: availability.label,
                        selected: _filters.availability == availability,
                        onTap: () => setState(() {
                          _filters = _filters.copyWith(
                            availability: availability,
                          );
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const _FilterLabel('Trust'),
                SwitchListTile.adaptive(
                  value: _filters.adminVerifiedOnly,
                  onChanged: (value) => setState(() {
                    _filters = _filters.copyWith(adminVerifiedOnly: value);
                  }),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Admin-verified only'),
                  subtitle: Text(
                    'Location or identity checked by Nijaora',
                    style: TextStyle(fontSize: 12, color: context.palette.muted),
                  ),
                  activeThumbColor: context.palette.ink,
                ),
                const SizedBox(height: AppSpacing.sm),
                const _FilterLabel('Minimum rating'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _Pill(
                      label: 'Any',
                      selected: _filters.minRating == null,
                      onTap: () => setState(() {
                        _filters = _filters.copyWith(clearMinRating: true);
                      }),
                    ),
                    for (final rating in const [3.0, 4.0, 4.5])
                      _Pill(
                        label: '${rating.toStringAsFixed(1)}+',
                        selected: _filters.minRating == rating,
                        onTap: () => setState(() {
                          _filters = _filters.copyWith(minRating: rating);
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_filters),
                child: Text(
                  _filters.activeCount == 0
                      ? 'Apply filters'
                      : 'Apply ${_filters.activeCount} filters',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.palette.ink : context.palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? context.palette.ink : context.palette.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? context.palette.cream : context.palette.ink,
            ),
          ),
        ),
      ),
    );
  }
}
