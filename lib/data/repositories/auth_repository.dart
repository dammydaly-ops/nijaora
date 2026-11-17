import '../../core/errors/app_failure.dart';
import '../models/app_user.dart';

/// The identifier a person uses to sign in.
///
/// Passwords are supported for both methods. Phone sign-in still uses the
/// Nigerian normalisation rules so `0803…`, `803…` and `+234803…` all resolve
/// to the same account.
enum AuthMethod {
  email,
  phone;

  static AuthMethod parse(String? raw) {
    return raw == phone.name ? phone : email;
  }

  String get label => switch (this) {
    AuthMethod.email => 'Email',
    AuthMethod.phone => 'Phone number',
  };
}

class OtpChallenge {
  const OtpChallenge({
    required this.id,
    this.isAutoVerified = false,
    this.demoCode,
  });

  final String id;
  final bool isAutoVerified;

  /// Demo-only code shown on the OTP entry screen. Always null for real SMS
  /// providers so production builds never reveal a sign-in code.
  final String? demoCode;
}

abstract class AuthRepository {
  Stream<AppUser?> watchUser();

  AppUser? get currentUser;

  Future<OtpChallenge> requestOtp(String rawPhone);

  Future<AppUser> verifyOtp({
    required String phone,
    required String code,
    required UserRole role,
    required OtpChallenge challenge,
  });

  /// Creates an account with an email or phone number and a password.
  ///
  /// Backends that do not support password auth fail with a user-safe
  /// [AppFailure] rather than silently falling back to OTP.
  Future<AppUser> signUpWithPassword({
    required AuthMethod method,
    required String identifier,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    throw const AppFailure(
      'Password sign-up is not available on this backend yet.',
      code: 'password_auth_unavailable',
    );
  }

  /// Signs an existing account in with its email/phone and password.
  Future<AppUser> signInWithPassword({
    required AuthMethod method,
    required String identifier,
    required String password,
  }) async {
    throw const AppFailure(
      'Password sign-in is not available on this backend yet.',
      code: 'password_auth_unavailable',
    );
  }

  Future<void> signOut();

  Future<void> updateRole(UserRole role);

  /// Saves the optional profile details collected on the sign-in screen.
  /// Empty values are ignored so an existing user can sign in without
  /// overwriting their profile.
  Future<void> updateProfile({String? displayName, String? email});
}
