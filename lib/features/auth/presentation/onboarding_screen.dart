import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/brand_mascot.dart';
import '../onboarding_seen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPage(
      eyebrow: 'WELCOME TO NIJAORA',
      title: 'Find your inner light.',
      body:
          'Trusted artisans and local shops, organised by the area you choose. '
          'No GPS. No home address. Just the people around you.',
      mascot: true,
    ),
    _OnboardingPage(
      eyebrow: 'YOUR AREA, YOUR PEOPLE',
      title: 'Start with your state and LGA.',
      body:
          'Choose a state, then a local government area, then an optional '
          'neighbourhood. Discovery stays relevant to where you actually are.',
      icon: Icons.location_on_rounded,
    ),
    _OnboardingPage(
      eyebrow: 'TRUST FIRST',
      title: 'See the person before you hire.',
      body:
          'Owner photos, real portfolios and honest reviews. Chat in the app, '
          'or continue on WhatsApp when that is easier for the business.',
      icon: Icons.verified_user_rounded,
    ),
    _OnboardingPage(
      eyebrow: 'SECURE FROM THE START',
      title: 'Create a password you control.',
      body:
          'Sign up with an email or phone number, then create a password. '
          'Coming back? Sign in with the same details. No one-time code for '
          'everyday sign-in.',
      icon: Icons.lock_outline_rounded,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish({bool signUp = false}) async {
    await ref.read(onboardingSeenProvider.notifier).complete();
    if (!mounted) return;
    context.go(signUp ? '/welcome?mode=signup' : '/welcome');
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish(signUp: true);
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.palette.cream, context.palette.amberWash],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _page = index),
                  itemBuilder: (context, index) {
                    return _OnboardingPageView(page: _pages[index]);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var index = 0; index < _pages.length; index++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: index == _page ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: index == _page
                                  ? context.palette.amberDeep
                                  : context.palette.border,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _page == _pages.length - 1
                            ? () => _finish(signUp: true)
                            : _next,
                        child: Text(
                          _page == _pages.length - 1
                              ? 'Create an account'
                              : 'Next',
                        ),
                      ),
                    ),
                    if (_page == _pages.length - 1) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _finish,
                          child: const Text('I already have an account'),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Email or phone. One password. No GPS.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
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

class _OnboardingPage {
  const _OnboardingPage({
    required this.eyebrow,
    required this.title,
    required this.body,
    this.icon,
    this.mascot = false,
  });

  final String eyebrow;
  final String title;
  final String body;
  final IconData? icon;
  final bool mascot;
}

class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (page.mascot)
                  const BrandMascot(size: 250)
                else
                  Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.palette.surface,
                      border: Border.all(color: context.palette.border),
                      boxShadow: [
                        BoxShadow(
                          color: context.palette.shadow,
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Icon(
                      page.icon,
                      size: 82,
                      color: context.palette.amberDeep,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  page.eyebrow,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.palette.amberDeep,
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall
                      ?.copyWith(fontSize: 31, height: 1.12),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  page.body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: context.palette.muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
