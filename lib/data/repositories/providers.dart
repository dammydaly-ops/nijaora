import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../demo/demo_catalog.dart';
import '../models/app_user.dart';
import '../models/business.dart';
import '../models/category.dart';
import '../models/conversation.dart';
import '../models/listing.dart';
import '../models/product_item.dart';
import '../models/review.dart';
import '../sources/supabase/supabase_auth_repository.dart';
import '../sources/supabase/supabase_business_repository.dart';
import 'auth_repository.dart';
import 'business_repository.dart';
import 'chat_repository.dart';
import 'demo/demo_auth_repository.dart';
import 'demo/demo_business_repository.dart';
import 'demo/demo_chat_repository.dart';
import 'demo/demo_location_repository.dart';
import 'fallback_business_repository.dart';
import 'firebase/firebase_auth_repository.dart';
import 'location_repository.dart';

/// Overridden in `bootstrap()` (and in tests) with a real instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider at startup');
});

final demoCatalogProvider = Provider<DemoCatalog>(
  (ref) => DemoCatalog.instance,
);

/// Available only when `SUPABASE_URL` and `SUPABASE_ANON_KEY` are configured.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  if (!AppConfig.supabaseEnabled) {
    throw StateError('Supabase is not available for this build.');
  }
  return Supabase.instance.client;
});

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return DemoLocationRepository(ref.watch(demoCatalogProvider));
});

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  final demo = DemoBusinessRepository(
    ref.watch(demoCatalogProvider),
    ref.watch(locationRepositoryProvider),
  );
  if (!AppConfig.supabaseEnabled) return demo;

  return FallbackBusinessRepository(
    primary: SupabaseBusinessRepository(
      ref.watch(supabaseClientProvider),
      ref.watch(locationRepositoryProvider),
    ),
    fallback: demo,
    publishWithPrimary: AppConfig.useSupabaseAuth && AppConfig.supabaseEnabled,
  );
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return DemoChatRepository(ref.watch(demoCatalogProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConfig.useFirebase) {
    final repository = FirebaseAuthRepository();
    ref.onDispose(repository.dispose);
    return repository;
  }
  if (AppConfig.useSupabaseAuth && AppConfig.supabaseEnabled) {
    final repository = SupabaseAuthRepository(
      ref.watch(supabaseClientProvider),
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  return DemoAuthRepository(ref.watch(sharedPreferencesProvider));
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchUser();
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).value;
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(businessRepositoryProvider).categories();
});

final publishedBusinessesProvider = FutureProvider<List<Business>>((ref) {
  return ref.watch(businessRepositoryProvider).allPublished();
});

final businessProvider = FutureProvider.family<Business?, String>((ref, id) {
  return ref.watch(businessRepositoryProvider).byId(id);
});

final productItemsProvider = FutureProvider<List<ProductItem>>((ref) async {
  final businesses = await ref.watch(publishedBusinessesProvider.future);
  final categories = await ref.watch(categoriesProvider.future);
  final categoryById = {
    for (final category in categories) category.id: category,
  };

  final items = <ProductItem>[];
  for (final business in businesses) {
    for (final listing in business.listings) {
      if (listing.type != ListingType.product) continue;
      items.add(
        ProductItem(
          listing: listing,
          business: business,
          category: listing.categoryId == null
              ? null
              : categoryById[listing.categoryId],
        ),
      );
    }
  }

  items.sort((a, b) {
    final byRating = b.rating.compareTo(a.rating);
    if (byRating != 0) return byRating;
    return a.title.compareTo(b.title);
  });
  return items;
});

final businessReviewsProvider = FutureProvider.family<List<Review>, String>((
  ref,
  id,
) {
  return ref.watch(businessRepositoryProvider).reviewsFor(id);
});

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref
      .watch(chatRepositoryProvider)
      .watchConversations(user.id, asBusiness: user.isBusiness);
});

final messagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  conversationId,
) {
  return ref.watch(chatRepositoryProvider).watchMessages(conversationId);
});
