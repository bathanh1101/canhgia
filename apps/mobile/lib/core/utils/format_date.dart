String _two(int n) => n.toString().padLeft(2, '0');

/// 28/09 (local time).
String formatDayMonth(DateTime d) {
  final l = d.toLocal();
  return '${_two(l.day)}/${_two(l.month)}';
}

/// 28/09/2026.
String formatDate(DateTime d) => '${formatDayMonth(d)}/${d.toLocal().year}';

/// 28/09/2026 14:05.
String formatDateTime(DateTime d) {
  final l = d.toLocal();
  return '${formatDate(d)} ${_two(l.hour)}:${_two(l.minute)}';
}
