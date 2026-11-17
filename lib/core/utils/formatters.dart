/// Naira formatting without locale-data dependencies.
String formatNaira(int amount) => '₦${_group(amount)}';

String formatNairaFrom(int amount) => 'From ${formatNaira(amount)}';

String _group(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$buffer';
}

String formatCompactCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final k = value / 1000;
    return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
  }
  return '${(value / 1000000).toStringAsFixed(1)}m';
}

/// "12 min", "1 hr 20 min", "2 days".
String formatResponseTime(int minutes) {
  if (minutes <= 0) return 'New';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours < 24) {
    return rest == 0 ? '$hours hr' : '$hours hr $rest min';
  }
  final days = hours ~/ 24;
  return days == 1 ? '1 day' : '$days days';
}
