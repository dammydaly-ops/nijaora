import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/nija_logo.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/providers.dart';
import '../guest_mode.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    required this.role,
    required this.challengeId,
    this.autoVerified = false,
    this.demoCode,
    this.name = '',
    this.email = '',
  });

  final String phone;
  final UserRole role;
  final String challengeId;
  final bool autoVerified;
  final String? demoCode;
  final String name;
  final String email;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _codeController = TextEditingController();
  late OtpChallenge _challenge;
  String? _demoCode;
  Timer? _timer;
  int _secondsLeft = 30;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _demoCode = widget.demoCode;
    _challenge = OtpChallenge(
      id: widget.challengeId,
      isAutoVerified: widget.autoVerified,
      demoCode: widget.demoCode,
    );
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
      if (_secondsLeft == 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.verifyOtp(
        phone: widget.phone,
        code: code,
        role: widget.role,
        challenge: _challenge,
      );
      final name = widget.name.trim();
      final email = widget.email.trim();
      if (name.isNotEmpty || email.isNotEmpty) {
        try {
          await auth.updateProfile(
            displayName: name.isEmpty ? null : name,
            email: email.isEmpty ? null : email,
          );
        } catch (_) {
          // The sign-in still succeeds if the optional profile details fail.
        }
      }
      ref.read(guestModeProvider.notifier).disable();
      if (!mounted) return;
      context.go(widget.role == UserRole.business ? '/registration' : '/');
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'We could not verify that code. Try again.');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final challenge = await ref
          .read(authRepositoryProvider)
          .requestOtp(widget.phone);
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _demoCode = challenge.demoCode;
        _resending = false;
      });
      _startTimer();
    } on AppFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _resending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'We could not resend the code. Please try again.';
          _resending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: [
            const NijaLogo(size: 34),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Enter your code',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'We sent a 6-digit code to ${prettyPhone(widget.phone)}.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.palette.muted),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: true,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: 12,
              ),
              onSubmitted: (_) => _verify(),
              decoration: InputDecoration(
                counterText: '',
                hintText: '000000',
                hintStyle: TextStyle(
                  letterSpacing: 12,
                  color: context.palette.border,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: TextStyle(color: context.palette.red, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _verifying ? null : _verify,
              child: _verifying
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: context.palette.cream,
                      ),
                    )
                  : const Text('Confirm code'),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: _secondsLeft > 0
                  ? Text(
                      'Resend code in ${_secondsLeft}s',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  : TextButton(
                      onPressed: _resending ? null : _resend,
                      child: const Text('Resend code'),
                    ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (AppConfig.showDemoOtp && _demoCode != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.palette.amberWash,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.science_rounded, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Demo code: $_demoCode — no SMS was sent.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _codeController.text = _demoCode!;
                      },
                      child: const Text('Use it'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Did not get the code? Make sure the number is correct and has '
              'network coverage. Codes expire after a few minutes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
