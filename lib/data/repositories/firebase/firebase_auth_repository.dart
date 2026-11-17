import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/auth_identity.dart';
import '../../../core/utils/phone.dart';
import '../../models/app_user.dart';
import '../auth_repository.dart';

/// Firebase phone authentication.
///
/// Android/iOS use `verifyPhoneNumber`. Web phone auth needs a reCAPTCHA
/// verifier and is intentionally not wired until a Firebase web app exists —
/// see docs/architecture.md.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance {
    _subscription = _auth.authStateChanges().listen(_handleAuthChange);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final _changes = StreamController<AppUser?>.broadcast();

  late final StreamSubscription<User?> _subscription;
  AppUser? _current;
  PhoneAuthCredential? _autoCredential;
  String? _verificationId;

  void dispose() {
    _subscription.cancel();
    _changes.close();
  }

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> watchUser() async* {
    if (_auth.currentUser != null && _current == null) {
      _current = await _loadProfile(_auth.currentUser!);
    }
    yield _current;
    yield* _changes.stream;
  }

  Future<void> _handleAuthChange(User? user) async {
    _current = user == null ? null : await _loadProfile(user);
    _changes.add(_current);
  }

  @override
  Future<OtpChallenge> requestOtp(String rawPhone) async {
    final phone = normalizeNigerianPhone(rawPhone);
    if (phone == null) {
      throw const AppFailure(
        'Enter a valid Nigerian phone number, for example 0803 123 4567.',
      );
    }

    if (kIsWeb) {
      throw const AppFailure(
        'Phone sign-in on web needs the Firebase web app and reCAPTCHA '
        'configuration. Use Android for now, or complete the web setup.',
        code: 'web-otp-unconfigured',
      );
    }

    final completer = Completer<OtpChallenge>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        _autoCredential = credential;
        if (!completer.isCompleted) {
          completer.complete(const OtpChallenge(id: '', isAutoVerified: true));
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(
            AppFailure(
              error.message ?? 'We could not send the code. Please try again.',
              code: error.code,
            ),
          );
        }
      },
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        if (!completer.isCompleted) {
          completer.complete(OtpChallenge(id: verificationId));
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
        if (!completer.isCompleted) {
          completer.complete(OtpChallenge(id: verificationId));
        }
      },
    );

    return completer.future;
  }

  @override
  Future<AppUser> verifyOtp({
    required String phone,
    required String code,
    required UserRole role,
    required OtpChallenge challenge,
  }) async {
    try {
      final credential =
          _autoCredential ??
          PhoneAuthProvider.credential(
            verificationId: challenge.id.isNotEmpty
                ? challenge.id
                : (_verificationId ?? ''),
            smsCode: code.trim(),
          );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw const AppFailure('Sign-in did not complete. Please try again.');
      }
      final profile = await _upsertProfile(user, role);
      _autoCredential = null;
      _current = profile;
      _changes.add(profile);
      return profile;
    } on FirebaseAuthException catch (error) {
      throw AppFailure(
        error.message ?? 'That code is not correct. Please try again.',
        code: error.code,
      );
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
    if (method == AuthMethod.phone) {
      throw const AppFailure(
        'Phone and password sign-in is available on the Supabase backend. '
        'Use email, or switch the auth backend to Supabase.',
        code: 'phone_password_unavailable',
      );
    }

    final email = normalizeEmail(identifier);
    if (!isValidEmail(email)) {
      throw const AppFailure(
        'Enter a valid email address, for example you@example.com.',
      );
    }
    final name = displayName.trim();
    if (name.length < 2) {
      throw const AppFailure('Enter your full name to create an account.');
    }
    final issue = passwordIssue(password);
    if (issue != null) throw AppFailure(issue);

    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;
      if (user == null) {
        throw const AppFailure(
          'We could not create your account. Please try again.',
        );
      }
      await user.updateDisplayName(name);
      await _firestore.collection('users').doc(user.uid).set({
        'email': email,
        'displayName': name,
        'role': role.name,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final profile = await _loadProfile(user);
      _current = profile;
      _changes.add(profile);
      return profile;
    } on FirebaseAuthException catch (error) {
      throw AppFailure(_passwordMessage(error, method));
    }
  }

  @override
  Future<AppUser> signInWithPassword({
    required AuthMethod method,
    required String identifier,
    required String password,
  }) async {
    if (method == AuthMethod.phone) {
      throw const AppFailure(
        'Phone and password sign-in is available on the Supabase backend. '
        'Use email, or switch the auth backend to Supabase.',
        code: 'phone_password_unavailable',
      );
    }

    final email = normalizeEmail(identifier);
    if (!isValidEmail(email)) {
      throw const AppFailure(
        'Enter a valid email address, for example you@example.com.',
      );
    }

    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;
      if (user == null) {
        throw const AppFailure(
          'Sign-in did not complete. Please try again.',
        );
      }
      final profile = await _loadProfile(user);
      _current = profile;
      _changes.add(profile);
      return profile;
    } on FirebaseAuthException catch (error) {
      throw AppFailure(_passwordMessage(error, method));
    }
  }

  Future<AppUser> _upsertProfile(User user, UserRole role) async {
    final doc = _firestore.collection('users').doc(user.uid);
    final snapshot = await doc.get();
    final existingRole = snapshot.data()?['role'] as String?;

    if (!snapshot.exists || existingRole == null) {
      await doc.set({
        'phone': user.phoneNumber,
        'displayName': user.displayName ?? role.label,
        if (user.email != null) 'email': user.email,
        'role': role.name,
        'createdAt': FieldValue.serverTimestamp(),
        'notificationSettings': {
          'messages': true,
          'reviews': true,
          'marketing': false,
        },
      }, SetOptions(merge: true));
    }

    return _loadProfile(user);
  }

  Future<AppUser> _loadProfile(User user) async {
    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      final createdAt = data['createdAt'];
      return AppUser(
        id: user.uid,
        phone: (data['phone'] as String?) ?? user.phoneNumber ?? '',
        displayName:
            (data['displayName'] as String?) ??
            user.displayName ??
            'Nijaora user',
        email: _trimmed(data['email'] as String?) ?? _trimmed(user.email),
        role: UserRole.parse(data['role'] as String?),
        createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      );
    } catch (_) {
      return AppUser(
        id: user.uid,
        phone: user.phoneNumber ?? '',
        displayName: user.displayName ?? 'Nijaora user',
        email: _trimmed(user.email),
        role: UserRole.customer,
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _current = null;
  }

  @override
  Future<void> updateRole(UserRole role) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'role': role.name,
    }, SetOptions(merge: true));
    final updated = await _loadProfile(user);
    _current = updated;
    _changes.add(updated);
  }

  @override
  Future<void> updateProfile({String? displayName, String? email}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final name = _trimmed(displayName);
    final mail = _trimmed(email);
    if (name == null && mail == null) return;

    if (name != null) await user.updateDisplayName(name);
    final updates = <String, dynamic>{};
    if (name != null) updates['displayName'] = name;
    if (mail != null) updates['email'] = mail;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(updates, SetOptions(merge: true));
    final updated = await _loadProfile(user);
    _current = updated;
    _changes.add(updated);
  }

  String? _trimmed(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _passwordMessage(FirebaseAuthException error, AuthMethod method) {
    final identifier = method == AuthMethod.email ? 'email' : 'phone number';
    switch (error.code) {
      case 'email-already-in-use':
      case 'account-exists-with-different-credential':
        return 'An account already exists for that $identifier. Sign in instead.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return 'That $identifier or password is not correct. Please try again.';
      case 'weak-password':
        return 'Choose a stronger password with at least '
            '$minimumPasswordLength characters.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment and try again.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      default:
        return error.message ?? 'We could not complete that sign-in. Try again.';
    }
  }
}
