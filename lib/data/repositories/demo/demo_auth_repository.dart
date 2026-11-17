import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/prefs_keys.dart';
import '../../../core/utils/auth_identity.dart';
import '../../../core/utils/phone.dart';
import '../../models/app_user.dart';
import '../auth_repository.dart';

/// Demo authentication. Persists the session on the device so hot restarts
/// behave like a real sign-in.
///
/// The demo backend supports email/password and phone/password accounts. It
/// keeps the older OTP path available for debug builds, but the normal sign-in
/// screen never calls it. Passwords are salted and hashed before they are
/// written to local storage.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository(this._prefs);

  final SharedPreferences _prefs;
  final _controller = StreamController<AppUser?>.broadcast();
  final _random = Random();

  AppUser? _current;
  bool _restored = false;
  String _pendingPhone = '';
  String? _activeIdentifier;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> watchUser() async* {
    if (!_restored) {
      _restored = true;
      _current = _restore();
    }
    yield _current;
    yield* _controller.stream;
  }

  AppUser? _restore() {
    final storedIdentifier = _prefs.getString(PrefsKeys.authIdentifier);
    final legacyPhone = _prefs.getString(PrefsKeys.authPhone);
    final methodName = _prefs.getString(PrefsKeys.authMethod);
    final method = methodName != null
        ? AuthMethod.parse(methodName)
        : storedIdentifier != null
            ? AuthMethod.email
            : AuthMethod.phone;
    final identifier = _nonEmpty(storedIdentifier) ?? _nonEmpty(legacyPhone);
    if (identifier == null) return null;

    _activeIdentifier = identifier;

    final role = UserRole.parse(_prefs.getString(PrefsKeys.authRole));
    final displayName =
        _prefs.getString(PrefsKeys.authDisplayName) ?? _defaultName(role);
    final phone = _nonEmpty(_prefs.getString(PrefsKeys.authPhone)) ??
        (method == AuthMethod.phone ? identifier : '');
    final email = _nonEmpty(_prefs.getString(PrefsKeys.authEmail)) ??
        (method == AuthMethod.email ? identifier : null);

    return AppUser(
      id: 'demo-customer',
      phone: phone,
      displayName: displayName,
      email: email,
      role: role,
      createdAt: DateTime.now(),
    );
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

    if (_prefs.getString(_passwordKey(normalized)) != null) {
      throw AppFailure(
        'An account already exists for that ${method == AuthMethod.email ? 'email' : 'phone number'}. '
        'Sign in instead.',
        code: 'account_exists',
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 450));

    final salt = _newSalt();
    await _prefs.setString(
      _passwordKey(normalized),
      '$salt:${_hashPassword(password, salt)}',
    );
    await _prefs.setString(_profileNameKey(normalized), name);
    await _prefs.setString(_profileRoleKey(normalized), role.name);
    if (method == AuthMethod.phone) {
      await _prefs.setString(_profilePhoneKey(normalized), normalized);
    } else {
      await _prefs.setString(_profileEmailKey(normalized), normalized);
    }

    final user = AppUser(
      id: 'demo-customer',
      phone: method == AuthMethod.phone
          ? normalized
          : (_nonEmpty(_prefs.getString(_profilePhoneKey(normalized))) ?? ''),
      displayName: name,
      email: method == AuthMethod.email
          ? normalized
          : _nonEmpty(_prefs.getString(_profileEmailKey(normalized))),
      role: role,
      createdAt: DateTime.now(),
    );
    await _persistSession(user, method, normalized);
    _current = user;
    _controller.add(user);
    return user;
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

    await Future<void>.delayed(const Duration(milliseconds: 350));

    final stored = _prefs.getString(_passwordKey(normalized));
    if (stored == null) {
      throw AppFailure(
        'We could not find an account for that ${method == AuthMethod.email ? 'email' : 'phone number'}. '
        'Create an account first.',
        code: 'account_not_found',
      );
    }

    final parts = stored.split(':');
    if (parts.length != 2 ||
        _hashPassword(password, parts.first) != parts.last) {
      throw const AppFailure(
        'That password is not correct. Please try again.',
        code: 'wrong_password',
      );
    }

    final role = UserRole.parse(
      _prefs.getString(_profileRoleKey(normalized)) ??
          _prefs.getString(PrefsKeys.authRole),
    );
    final name = _prefs.getString(_profileNameKey(normalized)) ??
        _defaultName(role);
    final phone = _nonEmpty(_prefs.getString(_profilePhoneKey(normalized))) ??
        (method == AuthMethod.phone ? normalized : '');
    final email =
        _nonEmpty(_prefs.getString(_profileEmailKey(normalized))) ??
            (method == AuthMethod.email ? normalized : null);

    final user = AppUser(
      id: 'demo-customer',
      phone: phone,
      displayName: name,
      email: email,
      role: role,
      createdAt: DateTime.now(),
    );
    await _persistSession(user, method, normalized);
    _current = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<OtpChallenge> requestOtp(String rawPhone) async {
    if (!AppConfig.showDemoOtp) {
      throw const AppFailure(
        'Phone sign-in is not available in this build yet. Please try again '
        'soon.',
      );
    }
    final phone = normalizeNigerianPhone(rawPhone);
    if (phone == null) {
      throw const AppFailure(
        'Enter a valid Nigerian phone number, for example 0803 123 4567.',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _pendingPhone = phone;
    return OtpChallenge(id: 'demo-challenge', demoCode: await _codeFor(phone));
  }

  Future<String> _codeFor(String phone) async {
    final key = '${PrefsKeys.demoOtpPrefix}$phone';
    final stored = _prefs.getString(key);
    if (stored != null && RegExp(r'^\d{6}$').hasMatch(stored)) {
      return stored;
    }

    final existingCodes = _prefs
        .getKeys()
        .where((item) => item.startsWith(PrefsKeys.demoOtpPrefix))
        .map(_prefs.getString)
        .whereType<String>()
        .toSet();
    String code;
    do {
      code = _random.nextInt(1000000).toString().padLeft(6, '0');
    } while (existingCodes.contains(code));
    await _prefs.setString(key, code);
    return code;
  }

  @override
  Future<AppUser> verifyOtp({
    required String phone,
    required String code,
    required UserRole role,
    required OtpChallenge challenge,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!AppConfig.showDemoOtp) {
      throw const AppFailure(
        'Phone sign-in is not available in this build yet. Please try again '
        'soon.',
      );
    }
    final normalized = normalizeNigerianPhone(phone) ?? _pendingPhone;
    final expected = _prefs.getString('${PrefsKeys.demoOtpPrefix}$normalized');
    if (expected == null || code.trim() != expected) {
      throw const AppFailure('That code is not correct. Please try again.');
    }

    final storedName = _prefs.getString(_profileNameKey(normalized));
    final storedEmail = _prefs.getString(_profileEmailKey(normalized));
    final user = AppUser(
      id: 'demo-customer',
      phone: normalized,
      displayName: storedName ?? _defaultName(role),
      email: _nonEmpty(storedEmail),
      role: role,
      createdAt: DateTime.now(),
    );
    await _persistSession(user, AuthMethod.phone, normalized);
    _current = user;
    _controller.add(user);
    return user;
  }

  String? _normalizeIdentifier(AuthMethod method, String raw) {
    if (method == AuthMethod.phone) return normalizeNigerianPhone(raw);
    final email = normalizeEmail(raw);
    return isValidEmail(email) ? email : null;
  }

  String _newSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }

  String _passwordKey(String identifier) =>
      '${PrefsKeys.demoPasswordPrefix}$identifier';

  String _profileNameKey(String identifier) =>
      '${PrefsKeys.demoUserPrefix}$identifier.name';

  String _profileEmailKey(String identifier) =>
      '${PrefsKeys.demoUserPrefix}$identifier.email';

  String _profilePhoneKey(String identifier) =>
      '${PrefsKeys.demoUserPrefix}$identifier.phone';

  String _profileRoleKey(String identifier) =>
      '${PrefsKeys.demoUserPrefix}$identifier.role';

  Future<void> _persistSession(
    AppUser user,
    AuthMethod method,
    String identifier,
  ) async {
    _activeIdentifier = identifier;
    await _prefs.setString(PrefsKeys.authIdentifier, identifier);
    await _prefs.setString(PrefsKeys.authMethod, method.name);
    await _prefs.setString(PrefsKeys.authPhone, user.phone);
    await _prefs.setString(PrefsKeys.authRole, user.role.name);
    await _prefs.setString(PrefsKeys.authDisplayName, user.displayName);
    if (user.email != null && user.email!.isNotEmpty) {
      await _prefs.setString(PrefsKeys.authEmail, user.email!);
      await _prefs.setString(_profileEmailKey(identifier), user.email!);
    } else {
      await _prefs.remove(PrefsKeys.authEmail);
    }
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> signOut() async {
    await _prefs.remove(PrefsKeys.authIdentifier);
    await _prefs.remove(PrefsKeys.authMethod);
    await _prefs.remove(PrefsKeys.authPhone);
    await _prefs.remove(PrefsKeys.authRole);
    await _prefs.remove(PrefsKeys.authDisplayName);
    await _prefs.remove(PrefsKeys.authEmail);
    await _prefs.remove(PrefsKeys.authBusinessId);
    _activeIdentifier = null;
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> updateRole(UserRole role) async {
    final user = _current;
    if (user == null) return;
    final updated = user.copyWith(role: role);
    _current = updated;
    await _prefs.setString(PrefsKeys.authRole, role.name);
    final identifier = _activeIdentifier;
    if (identifier != null) {
      await _prefs.setString(_profileRoleKey(identifier), role.name);
    }
    _controller.add(updated);
  }

  @override
  Future<void> updateProfile({String? displayName, String? email}) async {
    final user = _current;
    if (user == null) return;
    final name = _nonEmpty(displayName);
    final mail = _nonEmpty(email);
    if (name == null && mail == null) return;

    final updated = user.copyWith(displayName: name, email: mail);
    _current = updated;
    final identifier = _activeIdentifier ?? user.phone;
    if (name != null) {
      await _prefs.setString(PrefsKeys.authDisplayName, name);
      await _prefs.setString(_profileNameKey(identifier), name);
    }
    if (mail != null) {
      await _prefs.setString(PrefsKeys.authEmail, mail);
      await _prefs.setString(_profileEmailKey(identifier), mail);
    }
    _controller.add(updated);
  }

  String _defaultName(UserRole role) {
    return role == UserRole.business ? 'Business owner' : 'Nijaora customer';
  }
}
