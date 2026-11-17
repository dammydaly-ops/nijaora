import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/theme_mode.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/auth_identity.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/brand_mascot.dart';
import '../../../core/widgets/nija_logo.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/providers.dart';
import '../guest_mode.dart';

const _forest = Color(0xFF063D25);
const _forestMid = Color(0xFF0B5D3B);
const _forestLight = Color(0xFF0F6E45);
const _ivory = Color(0xFFF7FBF8);

enum _AuthMode { signIn, signUp }

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key, this.startInSignUp = false});

  /// Lets onboarding land directly on account creation, where the password
  /// fields are visible, instead of making a new visitor switch tabs first.
  final bool startInSignUp;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  AuthMethod _method = AuthMethod.email;
  UserRole _role = UserRole.customer;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  bool get _isSignUp => _mode == _AuthMode.signUp;

  @override
  void initState() {
    super.initState();
    _mode = widget.startInSignUp ? _AuthMode.signUp : _AuthMode.signIn;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final rawIdentifier = _identifierController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (_isSignUp && name.length < 2) {
      _setError('Enter your full name to create an account.');
      return;
    }

    final identifier = _method == AuthMethod.email
        ? normalizeEmail(rawIdentifier)
        : normalizeNigerianPhone(rawIdentifier);
    if (identifier == null ||
        (_method == AuthMethod.email && !isValidEmail(identifier))) {
      _setError(
        _method == AuthMethod.email
            ? 'Enter a valid email address, for example you@example.com.'
            : 'Enter a valid Nigerian phone number, for example 0803 123 4567.',
      );
      return;
    }

    final issue = passwordIssue(password);
    if (issue != null) {
      _setError(issue);
      return;
    }
    if (_isSignUp && password != confirm) {
      _setError('The passwords do not match. Please check them and try again.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final auth = ref.read(authRepositoryProvider);
      final user = _isSignUp
          ? await auth.signUpWithPassword(
              method: _method,
              identifier: rawIdentifier,
              password: password,
              displayName: name,
              role: _role,
            )
          : await auth.signInWithPassword(
              method: _method,
              identifier: rawIdentifier,
              password: password,
            );

      ref.read(guestModeProvider.notifier).disable();
      if (!mounted) return;
      final destination = _isSignUp && user.role == UserRole.business
          ? '/registration'
          : '/';
      context.go(destination);
    } on AppFailure catch (error) {
      if (!mounted) return;
      if (error.code == 'phone_confirmation_required') {
        final query = <String, String>{
          'phone': rawIdentifier,
          'role': _role.name,
          'cid': '',
          if (name.isNotEmpty) 'name': name,
        };
        context.push(Uri(path: '/otp', queryParameters: query).toString());
        return;
      }
      setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'We could not complete that sign-in. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setError(String message) {
    setState(() => _error = message);
  }

  void _switchMode(_AuthMode mode) {
    if (_mode == mode || _busy) return;
    setState(() {
      _mode = mode;
      _error = null;
      _passwordController.clear();
      _confirmController.clear();
      _obscurePassword = true;
      _obscureConfirm = true;
    });
  }

  void _switchMethod(AuthMethod method) {
    if (_method == method || _busy) return;
    setState(() {
      _method = method;
      _identifierController.clear();
      _error = null;
    });
  }

  void _browseAsGuest() {
    ref.read(guestModeProvider.notifier).enable();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.cream,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(flex: 5, child: _BrandPanel()),
                Expanded(flex: 6, child: _buildFormSide(context)),
              ],
            );
          }
          return _buildStacked(context);
        },
      ),
    );
  }

  Widget _buildFormSide(BuildContext context) {
    final palette = context.palette;
    return Stack(
      children: [
        Positioned(
          top: -140,
          right: -120,
          child: _SoftOrb(
            size: 420,
            color: palette.amber.withValues(alpha: 0.16),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _ThemeToggle(),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, viewport) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(32, 8, 32, 40),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (viewport.maxHeight - 48).clamp(
                            0.0,
                            double.infinity,
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: _buildCard(context),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStacked(BuildContext context) {
    final palette = context.palette;
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: _SoftOrb(
            size: 320,
            color: palette.amber.withValues(alpha: 0.13),
          ),
        ),
        Positioned(
          bottom: 120,
          left: -120,
          child: _SoftOrb(
            size: 280,
            color: palette.green.withValues(alpha: 0.08),
          ),
        ),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const NijaLogo(size: 34, showTagline: true),
                  _ThemeToggle(),
                ],
              ),
              const SizedBox(height: 20),
              const _CompactBrandHeader(),
              const SizedBox(height: 20),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _buildCard(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context) {
    final palette = context.palette;
    final isSignUp = _isSignUp;

    return Container(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ModeToggle(mode: _mode, onChanged: _switchMode),
            const SizedBox(height: 24),
            Text(
              isSignUp ? 'Create your account' : 'Welcome back',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: 30,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isSignUp
                  ? 'Join Nijaora with an email or phone number. Choose an '
                        'option below, then create a password.'
                  : 'Sign in with your email or phone number and the password '
                        'you created.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: 24),
            Text(
              isSignUp ? 'SIGN UP WITH' : 'SIGN IN WITH',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: palette.muted,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MethodChoice(
                    label: 'Email',
                    icon: Icons.mail_outline_rounded,
                    selected: _method == AuthMethod.email,
                    onTap: () => _switchMethod(AuthMethod.email),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _MethodChoice(
                    label: 'Phone number',
                    icon: Icons.phone_iphone_rounded,
                    selected: _method == AuthMethod.phone,
                    onTap: () => _switchMethod(AuthMethod.phone),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (isSignUp) ...[
              const _FieldLabel('Full name'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _nameController,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'e.g. Amaka Okafor',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            _FieldLabel(
              _method == AuthMethod.email ? 'Email address' : 'Phone number',
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _identifierController,
              keyboardType: _method == AuthMethod.email
                  ? TextInputType.emailAddress
                  : TextInputType.phone,
              autofillHints: _method == AuthMethod.email
                  ? const [AutofillHints.email]
                  : const [AutofillHints.telephoneNumber],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: _method == AuthMethod.email
                    ? 'you@example.com'
                    : '0803 123 4567',
                prefixIcon: Icon(
                  _method == AuthMethod.email
                      ? Icons.mail_outline_rounded
                      : Icons.phone_iphone_rounded,
                  size: 20,
                ),
                helperText: _method == AuthMethod.email
                    ? 'This is the address you will sign in with.'
                    : 'A Nigerian mobile number. We never need your GPS.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _FieldLabel(
              isSignUp ? 'Create a password' : 'Password',
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofillHints: isSignUp
                  ? const [AutofillHints.newPassword]
                  : const [AutofillHints.password],
              textInputAction: isSignUp
                  ? TextInputAction.next
                  : TextInputAction.done,
              onSubmitted: isSignUp ? null : (_) => _submit(),
              decoration: InputDecoration(
                hintText: isSignUp
                    ? 'At least 8 characters'
                    : 'Enter your password',
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? 'Show password'
                      : 'Hide password',
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                ),
              ),
            ),
            if (isSignUp) ...[
              const SizedBox(height: 6),
              Text(
                'Use at least $minimumPasswordLength characters. You will use '
                'this password next time you sign in.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _FieldLabel('Confirm password'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Repeat your password',
                  prefixIcon: const Icon(
                    Icons.lock_reset_rounded,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    tooltip: _obscureConfirm
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () => setState(
                      () => _obscureConfirm = !_obscureConfirm,
                    ),
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _FieldLabel('I am here as'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _RoleCard(
                      title: 'A customer',
                      subtitle: 'Find and hire',
                      icon: Icons.search_rounded,
                      selected: _role == UserRole.customer,
                      onTap: () => setState(() => _role = UserRole.customer),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _RoleCard(
                      title: 'A business',
                      subtitle: 'Get discovered',
                      icon: Icons.storefront_rounded,
                      selected: _role == UserRole.business,
                      onTap: () => setState(() => _role = UserRole.business),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: palette.redWash,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  border: Border.all(
                    color: palette.red.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: palette.red,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: palette.red,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: palette.cream,
                        ),
                      )
                    : Text(
                        isSignUp ? 'Create account' : 'Sign in',
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => _switchMode(
                        isSignUp ? _AuthMode.signIn : _AuthMode.signUp,
                      ),
                child: Text(
                  isSignUp
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account',
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _browseAsGuest,
                child: const Text('Browse as a guest'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'By continuing you agree to our Terms of Service and Privacy '
              'Policy. We never require your GPS location.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_forest, _forestMid, _forestLight],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -80,
            child: _SoftOrb(
              size: 360,
              color: Colors.white.withValues(alpha: 0.055),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _SoftOrb(
              size: 320,
              color: const Color(0xFF9BE3B5).withValues(alpha: 0.13),
            ),
          ),
          Positioned(
            top: 140,
            left: -130,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final short = constraints.maxHeight < 760;
                final mascotSize = short ? 180.0 : 248.0;
                final titleSize = short ? 36.0 : 46.0;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(46, 30, 46, 34),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 64).clamp(
                        0.0,
                        double.infinity,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const NijaLogo(
                          size: 40,
                          showTagline: true,
                          onDark: true,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: short ? 24 : 40,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: BrandMascot(size: mascotSize),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Find your inner light.',
                                style: TextStyle(
                                  color: _ivory,
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.4,
                                  height: 1.04,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'A marketplace for the people, products and '
                                'services shaping Nigeria — one neighbourhood '
                                'at a time.',
                                style: TextStyle(
                                  color: _ivory.withValues(alpha: 0.72),
                                  fontSize: 14.5,
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _TrustPoint(
                              icon: Icons.place_outlined,
                              text: 'Discover by state, LGA and '
                                  'neighbourhood.',
                            ),
                            const SizedBox(height: 12),
                            const _TrustPoint(
                              icon: Icons.verified_user_outlined,
                              text: 'Real people, real work, real reviews.',
                            ),
                            const SizedBox(height: 12),
                            const _TrustPoint(
                              icon: Icons.chat_bubble_outline_rounded,
                              text: 'Chat directly with local businesses.',
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'BUILT FOR NIGERIA  •  NO GPS REQUIRED',
                              style: TextStyle(
                                color: _ivory.withValues(alpha: 0.46),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactBrandHeader extends StatelessWidget {
  const _CompactBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_forest, _forestMid, _forestLight],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find your inner light.',
                  style: TextStyle(
                    color: _ivory,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Local talent, one conversation away.',
                  style: TextStyle(
                    color: _ivory.withValues(alpha: 0.72),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const BrandMascot(size: 96, showGlow: false),
        ],
      ),
    );
  }
}

class _TrustPoint extends StatelessWidget {
  const _TrustPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF9BE3B5)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              text,
              style: TextStyle(
                color: _ivory.withValues(alpha: 0.79),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () => ref.read(themeModeProvider.notifier).toggleDark(),
      style: IconButton.styleFrom(
        backgroundColor: context.palette.surface,
        foregroundColor: context.palette.amberDeep,
        side: BorderSide(color: context.palette.border),
      ),
      icon: Icon(
        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        size: 20,
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeTab(
              label: 'Sign in',
              selected: mode == _AuthMode.signIn,
              onTap: () => onChanged(_AuthMode.signIn),
            ),
          ),
          Expanded(
            child: _ModeTab(
              label: 'Sign up',
              selected: mode == _AuthMode.signUp,
              onTap: () => onChanged(_AuthMode.signUp),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
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
      color: selected ? context.palette.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? context.palette.ink : context.palette.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodChoice extends StatelessWidget {
  const _MethodChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: selected ? palette.amberWash : palette.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(
              color: selected ? palette.amberDeep : palette.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? palette.amberDeep : palette.muted,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? palette.ink : palette.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.palette.amberWash : context.palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(
              color: selected ? context.palette.amber : context.palette.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: context.palette.ink),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: context.palette.amberDeep,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
