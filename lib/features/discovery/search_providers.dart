import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/models/business.dart';
import '../../data/models/location_node.dart';
import '../../data/models/search.dart';
import '../../data/repositories/providers.dart';
import '../location/area_selection.dart';

class SearchQueryController extends Notifier<SearchQuery> {
  @override
  SearchQuery build() {
    final area = ref.watch(selectedAreaProvider);
    return SearchQuery(
      // Fallback keeps search usable before an area is chosen; UI still asks
      // the customer to pick an area.
      area: area ?? const AreaScope(stateId: 'ng-la'),
    );
  }

  void setKeyword(String keyword) {
    state = state.copyWith(keyword: keyword);
  }

  void setCategory(String? categoryId) {
    state = categoryId == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(categoryId: categoryId);
  }

  void setFilters(SearchFilters filters) {
    state = state.copyWith(filters: filters);
  }

  void setSort(SortOption sort) {
    state = state.copyWith(sort: sort);
  }

  void showNearby() {
    state = state.copyWith(includeNearby: true);
  }

  void searchWholeState() {
    state = state.copyWith(
      area: AreaScope(stateId: state.area.stateId),
    );
  }

  void refreshArea() {
    final area = ref.read(selectedAreaProvider);
    if (area != null) state = state.copyWith(area: area);
  }
}

final searchQueryProvider =
    NotifierProvider<SearchQueryController, SearchQuery>(
  SearchQueryController.new,
);

class SearchController extends AsyncNotifier<SearchState> {
  @override
  Future<SearchState> build() async {
    final query = ref.watch(searchQueryProvider);
    final page = await ref.watch(businessRepositoryProvider).search(
          query,
          page: 0,
          pageSize: AppConfig.searchPageSize,
        );
    return SearchState(
      hits: page.hits,
      totalExact: page.totalExact,
      totalNearby: page.totalNearby,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || state.isLoading) return;

    final query = ref.read(searchQueryProvider);
    try {
      final next = await ref.read(businessRepositoryProvider).search(
            query,
            page: current.page + 1,
            pageSize: AppConfig.searchPageSize,
          );
      state = AsyncData(current.append(next));
    } catch (_) {
      // Keep the loaded results; the footer retry stays available.
      state = AsyncData(current);
    }
  }
}

final searchControllerProvider =
    AsyncNotifierProvider<SearchController, SearchState>(SearchController.new);

final featuredBusinessesProvider = FutureProvider<List<Business>>((ref) {
  final area = ref.watch(selectedAreaProvider);
  return ref.watch(businessRepositoryProvider).featured(area);
});
