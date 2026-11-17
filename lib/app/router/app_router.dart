import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_user.dart';
import '../../data/models/category.dart';
import '../../data/repositories/providers.dart';
import '../../features/account/presentation/account_screen.dart';
import '../../features/auth/guest_mode.dart';
import '../../features/auth/onboarding_seen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/business/presentation/business_profile_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_thread_screen.dart';
import '../../features/discovery/home_screen.dart';
import '../../features/discovery/search_screen.dart';
import '../../features/products/presentation/product_detail_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/registration/presentation/registration_screen.dart';
import '../shell/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final guest = ref.read(guestModeProvider);
      final splashReady = ref.read(splashReadyProvider);
      final onboardingSeen = ref.read(onboardingSeenProvider);
      final path = state.matchedLocation;
      final isAuthRoute = path == '/welcome' || path == '/otp';
      final isOnboarding = path == '/onboarding';

      if (auth.isLoading || !splashReady) {
        return path == '/splash' ? null : '/splash';
      }

      final user = auth.value;
      if (!onboardingSeen) {
        return isOnboarding ? null : '/onboarding';
      }
      if (isOnboarding) {
        return (user != null || guest) ? '/' : '/welcome';
      }
      if (user == null && !guest) {
        return isAuthRoute ? null : '/welcome';
      }
      if (user != null && path == '/welcome') return '/';
      if ((user != null || guest) && path == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'];
          return WelcomeScreen(
            key: ValueKey('welcome-${mode ?? 'signin'}'),
            startInSignUp: mode == 'signup',
          );
        },
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return OtpScreen(
            phone: query['phone'] ?? '',
            role: UserRole.parse(query['role']),
            challengeId: query['cid'] ?? '',
            autoVerified: query['auto'] == '1',
            demoCode: query['demo'],
            name: query['name'] ?? '',
            email: query['email'] ?? '',
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/products',
            builder: (context, state) => const ProductsScreen(),
          ),
          GoRoute(
            path: '/chats',
            builder: (context, state) => const ChatListScreen(),
          ),
          GoRoute(
            path: '/account',
            builder: (context, state) => const AccountScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => SearchScreen(
          focusSearch: state.uri.queryParameters['focus'] == '1',
        ),
      ),
      GoRoute(
        path: '/business/:id',
        builder: (context, state) =>
            BusinessProfileScreen(businessId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/product/:businessId/:listingId',
        builder: (context, state) => ProductDetailScreen(
          businessId: state.pathParameters['businessId'] ?? '',
          listingId: state.pathParameters['listingId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) =>
            ChatThreadScreen(conversationId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/registration',
        builder: (context, state) => RegistrationScreen(
          initialKind: state.uri.queryParameters['kind'] == 'product'
              ? CategoryKind.product
              : CategoryKind.service,
        ),
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(guestModeProvider, (_, _) => notifyListeners());
    ref.listen(splashReadyProvider, (_, _) => notifyListeners());
    ref.listen(onboardingSeenProvider, (_, _) => notifyListeners());
  }
}
