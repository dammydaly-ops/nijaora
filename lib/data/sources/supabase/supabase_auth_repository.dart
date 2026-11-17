import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/auth_identity.dart';
import '../../../core/utils/phone.dart';
import '../../models/app_user.dart';
import '../../repositories/auth_repository.dart';

/// Real password authentication through Supabase.
///
/// Email/password works with the email provider. Phone/password additionally
/// needs the Phone provider and an SMS provider. If Supabase requires phone
/// confirmation at sign-up, the app sends the person to the code screen once;
/// returning sign-ins use the password.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client) {
    _authSubscription = _client.auth.onAuthStateChange.listen((state) async {
      final next = await _mapUser(state.session?.user);
      _cachedUser = next;
      if (!_changes.isClosed) _changes.add(next);
    });
  }

  final SupabaseClient _client;
  final _changes = StreamController<AppUser?>.broadcast();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  AppUser? get currentUser => _cachedUser;

  AppUser? _cachedUser;

  void dispose() {
    _authSubscription?.cancel();
    _changes.close();
  }

  @override
  Stream<AppUser?> watchUser() async* {
    if (_cachedUser == null && _client.auth.currentUser != null) {
      _cachedUser = await _mapUser(_client.auth.currentUser);
    }
    yield _cachedUser;
    yield* _changes.stream;
  }

  @override
  Future<OtpChallenge> requestOtp(String rawPhone) async {
    final phone = normalizeNigerianPhone(rawPhone);
    if (phone == null) {
      throw const AppFailure(
        'Enter a valid Nigerian phone number, for example 0803 123 4567.',
      );
    }

    try {
      await _client.auth.signInWithOtp(phone: phone);
    } on AuthException catch (error) {
      throw AppFailure(_friendlyMessage(error));
    }
    return const OtpChallenge(id: 'supabase-otp');
  }

  @override
  Future<AppUser> verifyOtp({
    required String phone,
    required String code,
    required UserRole role,
    required OtpChallenge challenge,
  }) async {
    final normalized = normalizeNigerianPhone(phone);
    if (normalized == null) {
      throw const AppFailure('That phone number is not valid.');
    }

    try {
      final response = await _client.auth.verifyOTP(
        phone: normalized,
        token: code.trim(),
        type: OtpType.sms,
      );
      final user = response.user;
      if (user == null) {
        throw const AppFailure('We could not verify that code. Try again.');
      }

      if (role == UserRole.business) {
        await _client
            .from('profiles')
            .update({'role': 'business'})
            .eq('id', user.id);
      }

      final mapped = await _mapUser(user, fallbackRole: role);
      if (mapped == null) {
        throw const AppFailure('We could not load your profile. Try again.');
      }
      _cachedUser = mapped;
      if (!_changes.isClosed) _changes.add(mapped);
      return mapped;
    } on AuthException catch (error) {
      throw AppFailure(_friendlyMessage(error));
    }
  }

  @override
  Future<AppUser> signUpWithPassword({
    required AuthMethod method,
    required String identifier,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    final normalized = _normalizeIdentifier(method, identifier);
    if (normalized == null) {
      throw AppFailure(
        method == AuthMethod.phone
            ? 'Enter a valid Nigerian phone number, for example 0803 123 4567.'
            : 'Enter a valid email address, for example you@example.com.',
      );
    }

    final name = displayName.trim();
    if (name.length < 2) {
      throw const AppFailure('Enter your full name to create an account.');
    }
    final issue = passwordIssue(password);
    if (issue != null) throw AppFailure(issue);

    final metadata = <String, dynamic>{
      'display_name': name,
      'role': role.name,
      'auth_method': method.name,
      if (method == AuthMethod.email) 'email': normalized,
      if (method == AuthMethod.phone) 'phone': normalized,
    };

    try {
      final response = method == AuthMethod.email
          ? await _client.auth.signUp(
              email: normalized,
              password: password,
              data: metadata,
            )
          : await _client.auth.signUp(
              phone: normalized,
              password: password,
              data: metadata,
            );
      final authUser = response.user;
      if (authUser == null) {
        throw const AppFailure(
          'We could not create your account. Please try again.',
        );
      }

      if (response.session == null) {
        if (method == AuthMethod.phone) {
          // Supabase asks for SMS confirmation at sign-up. The code screen
          // verifies it once; the password is already set for future sign-ins.
          throw const AppFailure(
            'Enter the code sent to your phone to finish creating your '
            'account.',
            code: 'phone_confirmation_required',
          );
        }
        throw AppFailure(
          'Check $normalized to confirm your account, then sign in with your '
          'password.',
          code: 'email_confirmation_required',
        );
      }

      if (role == UserRole.business) {
        try {
          await _client
              .from('profiles')
              .update({'role': role.name})
              .eq('id', authUser.id);
        } catch (_) {
          // The auth account is still valid; the profile trigger may catch up.
        }
      }

      final mapped = await _mapUser(authUser, fallbackRole: role);
      if (mapped == null) {
        throw const AppFailure(
          'We could not load your new account. Please sign in again.',
        );
      }
      _cachedUser = mapped;
      if (!_changes.isClosed) _changes.add(mapped);
      return mapped;
    } on AuthException catch (error) {
      throw AppFailure(_passwordMessage(error, method));
    }
  }

  @override
  Future<AppUser> signInWithPassword({
    required AuthMethod method,
    required String identifier,
    required String password,
  }) async {
    final normalized = _normalizeIdentifier(method, identifier);
    if (normalized == null) {
      throw AppFailure(
        method == AuthMethod.phone
            ? 'Enter a valid Nigerian phone number, for example 0803 123 4567.'
            : 'Enter a valid email address, for example you@example.com.',
      );
    }

    try {
      final response = method == AuthMethod.email
          ? await _client.auth.signInWithPassword(
              email: normalized,
              password: password,
            )
          : await _client.auth.signInWithPassword(
              phone: normalized,
              password: password,
            );
      final authUser = response.user;
      if (authUser == null) {
        throw const AppFailure(
          'Sign-in did not complete. Please try again.',
        );
      }
      final mapped = await _mapUser(authUser);
      if (mapped == null) {
        throw const AppFailure(
          'We could not load your profile. Please try again.',
        );
      }
      _cachedUser = mapped;
      if (!_changes.isClosed) _changes.add(mapped);
      return mapped;
    } on AuthException catch (error) {
      throw AppFailure(_passwordMessage(error, method));
    }
  }

  @override
  Future<void> signOut() async {
    _cachedUser = null;
    await _client.auth.signOut();
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<void> updateRole(UserRole role) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('profiles')
        .update({'role': role.name})
        .eq('id', user.id);
    _cachedUser = _cachedUser?.copyWith(role: role);
    if (_cachedUser != null && !_changes.isClosed) _changes.add(_cachedUser);
  }

  @override
  Future<void> updateProfile({String? displayName, String? email}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final name = _trimmed(displayName);
    final mail = _trimmed(email);
    if (name == null && mail == null) return;

    final metadata = <String, dynamic>{};
    if (name != null) metadata['display_name'] = name;
    if (mail != null) metadata['email'] = mail;
    try {
      await _client.auth.updateUser(UserAttributes(data: metadata));
    } catch (_) {
      // The auth metadata update is best-effort. The profile row is updated
      // separately so the display name still sticks when possible.
    }
    if (name != null) {
      try {
        await _client
            .from('profiles')
            .update({'display_name': name})
            .eq('id', user.id);
      } catch (_) {
        // The profile may not exist yet immediately after OTP verification.
      }
    }
    _cachedUser = _cachedUser?.copyWith(displayName: name, email: mail);
    if (_cachedUser != null && !_changes.isClosed) _changes.add(_cachedUser);
  }

  String? _normalizeIdentifier(AuthMethod method, String raw) {
    if (method == AuthMethod.phone) return normalizeNigerianPhone(raw);
    final email = normalizeEmail(raw);
    return isValidEmail(email) ? email : null;
  }

  String? _trimmed(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<AppUser?> _mapUser(User? user, {UserRole? fallbackRole}) async {
    if (user == null) return null;

    String? displayName;
    String? roleName;
    try {
      final profile = await _client
          .from('profiles')
          .select('display_name, role')
          .eq('id', user.id)
          .maybeSingle();
      displayName = profile?['display_name'] as String?;
      roleName = profile?['role'] as String?;
    } catch (_) {
      // Auth still works if the profile row is temporarily unavailable.
    }

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    displayName = (displayName == null || displayName.trim().isEmpty)
        ? metadata['display_name'] as String?
        : displayName;
    roleName ??= metadata['role'] as String?;
    final email =
        _trimmed(metadata['email'] as String?) ?? _trimmed(user.email);
    final phone =
        _trimmed(user.phone) ?? _trimmed(metadata['phone'] as String?) ?? '';

    return AppUser(
      id: user.id,
      phone: phone,
      displayName: (displayName == null || displayName.trim().isEmpty)
          ? 'Nijaora user'
          : displayName.trim(),
      email: email,
      role: fallbackRole ?? UserRole.parse(roleName),
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
    );
  }

  String _friendlyMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('rate') || message.contains('too many')) {
      return 'Too many attempts. Wait a moment and try again.';
    }
    if (message.contains('invalid') || message.contains('expired')) {
      return 'That code is not correct or has expired.';
    }
    if (message.contains('sms') || message.contains('provider')) {
      return 'SMS sign-in is not configured yet. Please try again later.';
    }
    return 'We could not send or verify that code. Try again.';
  }

  String _passwordMessage(AuthException error, AuthMethod method) {
    final message = error.message.toLowerCase();
    final identifier =
        method == AuthMethod.email ? 'email' : 'phone number';

    if (message.contains('already') ||
        message.contains('registered') ||
        message.contains('exists')) {
      return 'An account already exists for that $identifier. Sign in instead.';
    }
    if (message.contains('weak') ||
        message.contains('leaked') ||
        message.contains('characters')) {
      return 'Choose a stronger password with at least '
          '$minimumPasswordLength characters.';
    }
    if (message.contains('invalid') ||
        message.contains('credentials') ||
        message.contains('password')) {
      return 'That $identifier or password is not correct. Please try again.';
    }
    if (message.contains('not confirmed') ||
        message.contains('confirm your')) {
      return method == AuthMethod.email
          ? 'Confirm your email address first, then sign in with your password.'
          : 'Confirm your phone number first, then sign in with your password.';
    }
    if (message.contains('rate') || message.contains('too many')) {
      return 'Too many attempts. Wait a moment and try again.';
    }
    if (message.contains('phone') &&
        (message.contains('disabled') ||
            message.contains('not enabled') ||
            message.contains('provider') ||
            message.contains('sms'))) {
      return 'Phone sign-in is not configured yet. Use email for now or try '
          'again later.';
    }
    return 'We could not complete that sign-in. Please try again.';
  }
}
