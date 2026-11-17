import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/theme_mode.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/nija_logo.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/providers.dart';
import '../../auth/guest_mode.dart';
import '../../location/area_labels.dart';
import '../../location/area_picker_sheet.dart';
import '../../location/area_selection.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _messagePush = true;
  bool _reviewPush = true;

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You can sign back in with the same email or phone number and your '
          'password. Your chats and reviews stay in your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authRepositoryProvider).signOut();
    ref.read(guestModeProvider.notifier).disable();
    if (mounted) context.go('/welcome');
  }

  void _signIn() {
    ref.read(guestModeProvider.notifier).disable();
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final locations = ref.watch(locationRepositoryProvider);
    final area = ref.watch(selectedAreaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.lg),
            child: Center(child: NijaLogo(size: 26)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          if (user == null)
            _GuestCard(onSignIn: _signIn)
          else
            _ProfileCard(user: user),
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('Discovery'),
          _MenuTile(
            icon: Icons.place_outlined,
            title: 'Your search area',
            subtitle: areaChipLabel(area, locations),
            onTap: () => showAreaPicker(context),
          ),
          _MenuTile(
            icon: Icons.location_off_outlined,
            title: 'No GPS needed',
            subtitle: 'Nijaora never asks for your home address to browse',
            onTap: () => _showInfo(
              'Your privacy',
              'You choose the state and LGA to search. We do not request GPS '
                  'or your home address. Businesses show only the area they '
                  'choose to publish.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel('Business'),
          _MenuTile(
            icon: Icons.storefront_outlined,
            title: user?.isBusiness == true
                ? 'Your business tools'
                : 'List your business',
            subtitle: user?.isBusiness == true
                ? 'Update your profile and reach more customers'
                : 'Free profile, chats and reviews',
            onTap: () {
              if (user == null) {
                _signIn();
              } else {
                context.push('/registration');
              }
            },
          ),
          _MenuTile(
            icon: Icons.qr_code_2_rounded,
            title: 'Share your profile',
            subtitle: 'Public link and QR code',
            onTap: () {
              if (user == null) {
                _signIn();
              } else if (user.isBusiness) {
                context.push('/registration');
              } else {
                _showInfo(
                  'Your public page',
                  'When you publish a business, you get a shareable link and a '
                      'QR code for your shop or business card.',
                );
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel('Appearance'),
          const _ThemeModeTile(),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel('Notifications'),
          SwitchListTile.adaptive(
            value: _messagePush,
            onChanged: (value) => setState(() => _messagePush = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('New messages'),
            subtitle: Text(
              'Push and in-app. Safety notices cannot be turned off.',
              style: TextStyle(fontSize: 12, color: context.palette.muted),
            ),
            activeThumbColor: context.palette.ink,
          ),
          SwitchListTile.adaptive(
            value: _reviewPush,
            onChanged: (value) => setState(() => _reviewPush = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('Reviews and replies'),
            subtitle: Text(
              'Know when someone reviews your business.',
              style: TextStyle(fontSize: 12, color: context.palette.muted),
            ),
            activeThumbColor: context.palette.ink,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel('Support'),
          _MenuTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & safety',
            subtitle: 'Scams, reporting and how Nijaora works',
            onTap: () => _showInfo(
              'Help & safety',
              'Ã¢â‚¬Â¢ Meet in public or at the business location when possible.\n'
                  'Ã¢â‚¬Â¢ Agree the price before work starts.\n'
                  'Ã¢â‚¬Â¢ Nijaora does not take payments. Never send a deposit to '
                  'someone you have not verified.\n'
                  'Ã¢â‚¬Â¢ Use Report on a profile, review or message. Admins review '
                  'reports and record every action.',
            ),
          ),
          _MenuTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy & data',
            subtitle: 'What we collect and how to delete your account',
            onTap: () => _showInfo(
              'Privacy & data',
              'We collect your email or phone number, profile details, chats '
                  'and usage events to run Nijaora. Your GPS is never required. '
                  'You can request account deletion from this screen; reviews '
                  'are kept anonymised so ratings stay consistent.',
            ),
          ),
          _MenuTile(
            icon: Icons.info_outline_rounded,
            title: 'About Nijaora',
            subtitle: 'Version 1.0.0 Ã‚Â· ${AppConfig.useFirebase ? 'Live' : 'Demo'}',
            onTap: () => _showInfo(
              'About Nijaora',
              'Nijaora connects customers with artisans, service providers and '
                  'local sellers in the area they choose.\n\n'
                  'Find your inner light.',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (user != null) ...[
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.palette.red,
                side: BorderSide(color: context.palette.red),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => _showInfo(
                'Delete account',
                'Account deletion is handled by support in the pilot. Email '
                    'support@nijaora.com from your registered number and we '
                    'will remove or anonymise your data under the retention '
                    'rules. A self-serve deletion flow ships before public '
                    'launch.',
              ),
              child: Text(
                'Request account deletion',
                style: TextStyle(color: context.palette.red),
              ),
            ),
          ],
          if (!AppConfig.useFirebase) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.palette.amberWash,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: const Row(
                children: [
                  Icon(Icons.science_rounded, size: 18),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Demo mode Ã‚Â· sample data stored on this device. '
                      'Switch to Firebase with AUTH_BACKEND=firebase.',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showInfo(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(message, style: const TextStyle(height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.ink,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.palette.amber,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              user.displayName.trim().isEmpty
                  ? 'N'
                  : user.displayName.trim().substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.palette.ink,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.palette.cream,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.phone.trim().isNotEmpty
                      ? prettyPhone(user.phone)
                      : (user.email ?? 'Nijaora member'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.palette.cream.withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.palette.cream.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    user.role.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.palette.amber,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.verified_rounded,
            size: 18,
            color: context.palette.green,
          ),
        ],
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Browsing as a guest',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Sign in with your email or phone and password to chat, review and '
            'keep your enquiries.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSignIn,
              child: Text('Sign in'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeTile extends ConsumerWidget {
  const _ThemeModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final systemDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final effectiveDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system && systemDark);

    return SwitchListTile.adaptive(
      value: effectiveDark,
      onChanged: (value) => ref
          .read(themeModeProvider.notifier)
          .setMode(value ? ThemeMode.dark : ThemeMode.light),
      contentPadding: EdgeInsets.zero,
      secondary: Icon(
        effectiveDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
        color: context.palette.amberDeep,
      ),
      title: const Text('Dark mode'),
      subtitle: Text(
        mode == ThemeMode.system
            ? 'Following your device. Toggle to choose light or dark.'
            : effectiveDark
                ? 'Dark green on black'
                : 'Dark green on white',
        style: TextStyle(fontSize: 12, color: context.palette.muted),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: context.palette.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 19, color: context.palette.inkSoft),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11.5, color: context.palette.muted),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 19,
        color: context.palette.muted,
      ),
      onTap: onTap,
    );
  }
}
