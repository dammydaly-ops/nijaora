import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_palette.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/config/app_config.dart';
import '../../core/services/analytics_service.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/skeletons.dart';
import '../../data/models/search.dart';
import '../../data/repositories/providers.dart';
import '../discovery/search_providers.dart';
import '../discovery/widgets/business_card.dart';
import '../discovery/widgets/filters_sheet.dart';
import '../location/area_labels.dart';
import '../location/area_picker_sheet.dart';
import '../location/area_selection.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.focusSearch = false});

  final bool focusSearch;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _searchController;
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(searchQueryProvider).keyword,
    );
    _searchController.addListener(() => setState(() {}));
    _scrollController.addListener(_onScroll);
    if (widget.focusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 320) {
      ref.read(searchControllerProvider.notifier).loadMore();
    }
  }

  void _submit(String value) {
    ref.read(searchQueryProvider.notifier).setKeyword(value.trim());
    FocusScope.of(context).unfocus();
  }

  Future<void> _openFilters(SearchFilters current) async {
    final updated = await showFilterSheet(context, current);
    if (updated != null) {
      ref.read(searchQueryProvider.notifier).setFilters(updated);
    }
  }

  Future<void> _openAreaPicker() async {
    final query = ref.read(searchQueryProvider);
    await showAreaPicker(context);
    if (!mounted) return;
    // Re-apply the typed keyword after the area change rebuilds the query.
    ref.read(searchQueryProvider.notifier).setKeyword(_searchController.text);
    if (query.keyword.trim().isEmpty) {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final locations = ref.watch(locationRepositoryProvider);
    final results = ref.watch(searchControllerProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };
    final areaName = areaInlineLabel(query.area, locations);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: SizedBox(
          height: 46,
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: _submit,
            decoration: InputDecoration(
              hintText: 'What do you need?',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              prefixIconConstraints: const BoxConstraints(minWidth: 38),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _submit('');
                      },
                    ),
            ),
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Filters',
                onPressed: () => _openFilters(query.filters),
                icon: const Icon(Icons.tune_rounded),
              ),
              if (query.filters.activeCount > 0)
                Positioned(
                  top: 8,
                  right: 6,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: context.palette.amberDeep,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${query.filters.activeCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<SortOption>(
            tooltip: 'Sort',
            icon: const Icon(Icons.swap_vert_rounded),
            initialValue: query.sort,
            onSelected: (sort) {
              ref.read(searchQueryProvider.notifier).setSort(sort);
            },
            itemBuilder: (context) => [
              for (final sort in SortOption.values)
                PopupMenuItem(
                  value: sort,
                  child: Row(
                    children: [
                      Icon(
                        sort == query.sort
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 17,
                        color: sort == query.sort
                            ? context.palette.amberDeep
                            : context.palette.muted,
                      ),
                      const SizedBox(width: 8),
                      Text(sort.label),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Flexible(
                  child: _HeaderChip(
                    icon: Icons.place_rounded,
                    label: areaChipLabel(
                      ref.watch(selectedAreaProvider),
                      locations,
                    ),
                    onTap: _openAreaPicker,
                  ),
                ),
                if (query.categoryId != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: _HeaderChip(
                      icon: Icons.category_outlined,
                      label: categoryNames[query.categoryId] ?? 'Category',
                      onTap: () {
                        ref
                            .read(searchQueryProvider.notifier)
                            .setCategory(null);
                      },
                      trailing: Icons.close_rounded,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Showing $areaName',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  query.sort.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.palette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: results.when(
              loading: () => const BusinessListSkeleton(),
              error: (error, _) => ErrorView(
                message: 'We could not load results. Check your connection.',
                onRetry: () => ref.invalidate(searchControllerProvider),
              ),
              data: (state) {
                if (state.hits.isEmpty) {
                  return _emptyState(query, areaName);
                }
                return _results(state, query, categoryNames);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(
    SearchState state,
    SearchQuery query,
    Map<String, String> categoryNames,
  ) {
    final locations = ref.watch(locationRepositoryProvider);
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Text(
              '${state.totalExact} ${state.totalExact == 1 ? 'match' : 'matches'}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (state.totalNearby > 0) ...[
              const SizedBox(width: 6),
              Text(
                'Ã‚Â· ${state.totalNearby} nearby',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      if (state.totalExact == 0 && state.totalNearby > 0)
        Container(
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.palette.amberWash,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Row(
            children: [
              const Icon(Icons.near_me_rounded, size: 17),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'No one in ${areaInlineLabel(query.area, locations)} yet. '
                  'Here are businesses in nearby LGAs.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.palette.ink,
                      ),
                ),
              ),
            ],
          ),
        ),
    ];

    var nearbyHeaderShown = false;
    for (final hit in state.hits) {
      if (hit.isNearby && !nearbyHeaderShown) {
        nearbyHeaderShown = true;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.near_me_rounded, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Nearby LGAs',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 6),
                Text(
                  'Ã‚Â· clearly labelled',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.md,
          ),
          child: BusinessCard(
            business: hit.business,
            categoryName:
                categoryNames[hit.business.primaryCategoryId] ?? 'Business',
            areaLabel: businessAreaLabel(hit.business, locations),
            isNearby: hit.isNearby,
            onTap: () => context.push('/business/${hit.business.id}'),
          ),
        ),
      );
    }

    if (state.hasMore) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: OutlinedButton(
            onPressed: () =>
                ref.read(searchControllerProvider.notifier).loadMore(),
            child: const Text('Load more'),
          ),
        ),
      );
    } else {
      children.add(const SizedBox(height: AppSpacing.xl));
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      children: children,
    );
  }

  Widget _emptyState(SearchQuery query, String areaName) {
    final locations = ref.read(locationRepositoryProvider);
    final state = locations.byId(query.area.stateId);
    final stateName = state?.name ?? 'the state';
    final hasFilters = query.filters.activeCount > 0;
    final hasKeyword = query.keyword.trim().isNotEmpty;

    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No matches in $areaName',
      message: hasKeyword
          ? 'Nothing matched "${query.keyword.trim()}". Try a different '
              'spelling, a broader area, or remove filters.'
          : 'We are still onboarding businesses here. You can search the whole '
              'state or get notified when someone joins.',
      actions: [
        FilledButton(
          onPressed: () {
            ref.read(searchQueryProvider.notifier).searchWholeState();
          },
          child: Text(
            query.area.isWholeState
                ? 'Remove filters'
                : 'Search all of $stateName',
          ),
        ),
        if (hasFilters || query.categoryId != null)
          OutlinedButton(
            onPressed: () {
              ref.read(searchQueryProvider.notifier).setFilters(
                    const SearchFilters(),
                  );
              ref.read(searchQueryProvider.notifier).setCategory(null);
            },
            child: const Text('Clear filters'),
          ),
        OutlinedButton(
          onPressed: _openAreaPicker,
          child: const Text('Choose another area'),
        ),
        TextButton(
          onPressed: _notifyMe,
          child: const Text('Notify me when someone joins'),
        ),
      ],
    );
  }

  void _notifyMe() {
    ref.read(analyticsProvider).track('notify_me_requested', {
      'lgaId': ref.read(searchQueryProvider).area.lgaId,
      'keyword': ref.read(searchQueryProvider).keyword,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved. We will let you know when businesses join this area. '
          '${AppConfig.useFirebase ? '' : '(Demo: saved on this device only.)'}',
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing = Icons.keyboard_arrow_down_rounded,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final IconData trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: context.palette.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: context.palette.muted),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(trailing, size: 15, color: context.palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}
