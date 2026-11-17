import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product_item.dart';
import '../../../data/reference/catalog_taxonomy.dart';
import '../../../data/repositories/providers.dart';
import '../widgets/product_card.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _categoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(productItemsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.value ?? const <Category>[];
    final parents = productParents(categories);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: context.palette.ink,
          onRefresh: () async {
            ref.invalidate(productItemsProvider);
            try {
              await ref.read(productItemsProvider.future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Products',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ready-made finds from trusted Nigerian sellers.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/registration?kind=product'),
                    icon: const Icon(Icons.add_business_outlined, size: 17),
                    label: const Text('Sell'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search clothes, furniture, food...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CategoryChip(
                      label: 'All products',
                      selected: _categoryId == null,
                      onTap: () => setState(() => _categoryId = null),
                    ),
                    for (final parent in parents) ...[
                      const SizedBox(width: 8),
                      _CategoryChip(
                        label: parent.name,
                        selected: _categoryId == parent.id,
                        onTap: () => setState(() {
                          _categoryId =
                              _categoryId == parent.id ? null : parent.id;
                        }),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              itemsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => ErrorView(
                  title: 'Products are unavailable',
                  message: 'We could not load products right now.',
                  onRetry: () => ref.invalidate(productItemsProvider),
                ),
                data: (items) {
                  final filtered = _filter(items);
                  if (filtered.isEmpty) {
                    return EmptyState(
                      title: _query.isEmpty && _categoryId == null
                          ? 'No products yet'
                          : 'No products match',
                      message: _query.isEmpty && _categoryId == null
                          ? 'Product sellers will appear here as they join '
                              'Nijaora.'
                          : 'Try another category or a different search.',
                      icon: Icons.shopping_bag_outlined,
                      actions: [
                        OutlinedButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                              _categoryId = null;
                            });
                          },
                          child: const Text('Show all products'),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${filtered.length} '
                            '${filtered.length == 1 ? 'product' : 'products'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          if (_categoryId != null)
                            Text(
                              'Filtered',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: context.palette.amberDeep,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppSpacing.md,
                          crossAxisSpacing: AppSpacing.md,
                          childAspectRatio: 0.58,
                        ),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return ProductCard(
                            item: item,
                            onTap: () => context.push(
                              '/product/${item.business.id}/${item.listing.id}',
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<ProductItem> _filter(List<ProductItem> items) {
    final query = _query.trim().toLowerCase();
    return items.where((item) {
      if (_categoryId != null) {
        final category = item.category;
        if (category == null) return false;
        if (category.id != _categoryId &&
            category.parentId != _categoryId) {
          return false;
        }
      }
      if (query.isEmpty) return true;
      final haystack = [
        item.title,
        item.description,
        item.businessName,
        item.areaLabel,
        item.category?.name ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? context.palette.ink : context.palette.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected
                  ? context.palette.cream
                  : context.palette.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}
