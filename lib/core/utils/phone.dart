/// Normalises Nigerian mobile numbers to `+234XXXXXXXXXX`.
///
/// Accepts `0803 123 4567`, `8031234567`, `2348031234567` and
/// `+2348031234567`. Returns null when the number is not a valid Nigerian
/// mobile number.
String? normalizeNigerianPhone(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('234')) digits = digits.substring(3);
  if (digits.startsWith('0')) digits = digits.substring(1);
  if (digits.length != 10) return null;
  if (!RegExp(r'^(70|71|80|81|90|91)\d{8}$').hasMatch(digits)) return null;
  return '+234$digits';
}

/// Human-friendly format for display: `0803 123 4567`.
String prettyPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final local = digits.startsWith('234')
      ? '0${digits.substring(3)}'
      : digits.startsWith('0')
          ? digits
          : '0$digits';
  if (local.length != 11) return phone;
  return '${local.substring(0, 4)} ${local.substring(4, 7)} '
      '${local.substring(7)}';
}

/// Business names must be 2-60 characters and include at least one letter.
bool isValidBusinessName(String name) {
  final trimmed = name.trim();
  if (trimmed.length < 2 || trimmed.length > 60) return false;
  return RegExp(r'[A-Za-z]').hasMatch(trimmed);
}

bool isOnlyDigitsOrSymbols(String value) {
  return !RegExp(r'[A-Za-z]').hasMatch(value.trim());
}
