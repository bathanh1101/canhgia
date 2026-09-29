/// 1250000 -> "1.250.000đ". Money is always integer VND.
String formatVnd(int amount) {
  final digits = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$bufđ';
}

/// Compact form for tight spots: 4860000 -> "4,86tr", 250000 -> "250K".
String formatVndCompact(int amount) {
  if (amount >= 1000000) {
    final v = (amount / 10000).round() / 100;
    return '${v.toString().replaceAll('.', ',')}tr';
  }
  if (amount >= 1000) return '${(amount / 1000).round()}K';
  return '$amount';
}
