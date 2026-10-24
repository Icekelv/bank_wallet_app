String _group(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// 12345.6 -> "12,345.60"
String amountText(double v, {int decimals = 2}) {
  final neg = v < 0;
  final fixed = v.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = _group(parts[0]);
  final out = parts.length > 1 ? '$whole.${parts[1]}' : whole;
  return neg ? '-$out' : out;
}

/// Currency text, e.g. "$12,345.60". Prices under 1 get more decimals.
String money(String symbol, double v, {bool signed = false}) {
  final decimals = v.abs() > 0 && v.abs() < 1 ? 4 : 2;
  final body = '$symbol${amountText(v.abs(), decimals: decimals)}';
  if (signed) return v < 0 ? '−$body' : '+$body';
  return v < 0 ? '−$body' : body;
}

/// Whole part and cents separately, for big balances with dimmed cents.
(String, String) moneyParts(String symbol, double v) {
  final full = amountText(v.abs());
  final dot = full.lastIndexOf('.');
  final sign = v < 0 ? '−' : '';
  return ('$sign$symbol${full.substring(0, dot)}', full.substring(dot));
}

/// Coin quantity without trailing zeros: 0.41200000 -> "0.412".
String coin(double v) {
  var s = v.toStringAsFixed(8);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

String percent(double v) => '${v >= 0 ? '+' : '−'}${v.abs().toStringAsFixed(2)}%';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _two(int n) => n.toString().padLeft(2, '0');

/// "Today, 09:12", "Yesterday", "Oct 21".
String friendlyDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today, ${_two(d.hour)}:${_two(d.minute)}';
  if (diff == 1) return 'Yesterday, ${_two(d.hour)}:${_two(d.minute)}';
  final base = '${_months[d.month - 1]} ${d.day}';
  return d.year == now.year ? base : '$base, ${d.year}';
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}
