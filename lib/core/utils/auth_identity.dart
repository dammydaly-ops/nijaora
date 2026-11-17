final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Lower-cases and trims an email address so sign-up and sign-in resolve to
/// the same account.
String normalizeEmail(String input) => input.trim().toLowerCase();

bool isValidEmail(String input) => _emailPattern.hasMatch(input.trim());

const minimumPasswordLength = 8;

/// Returns copy-safe feedback when a password is too weak, or null when it is
/// acceptable. Both the UI and the repositories call this so the rules cannot
/// drift apart.
String? passwordIssue(String password) {
  if (password.length < minimumPasswordLength) {
    return 'Use at least $minimumPasswordLength characters for your password.';
  }
  return null;
}
