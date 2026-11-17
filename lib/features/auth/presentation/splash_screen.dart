import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/brand_mascot.dart';
import '../../../core/widgets/nija_logo.dart';

class SplashReadyController extends Notifier<bool> {
  @override
  bool build() => false;

  void complete() {
    if (!state) state = true;
  }
}

final splashReadyProvider = NotifierProvider<SplashReadyController, bool>(
  SplashReadyController.new,
);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1300), () {
      if (mounted) ref.read(splashReadyProvider.notifier).complete();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.palette.cream,
              context.palette.amberWash,
              context.palette.cream,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.92 + value * 0.08,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMascot(size: 250),
                  const SizedBox(height: AppSpacing.lg),
                  const NijaLogo(size: 42, showTagline: true),
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: 96,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: context.palette.border,
                        color: context.palette.amberDeep,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Preparing your area…',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.palette.muted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppConfig.tagline,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.palette.muted,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
