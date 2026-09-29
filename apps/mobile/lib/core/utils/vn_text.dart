const _groups = <String, String>{
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<String, String> _fold = {
  for (final e in _groups.entries) ...{
    for (final ch in e.value.split('')) ch: e.key,
    for (final ch in e.value.toUpperCase().split('')) ch: e.key.toUpperCase(),
  },
};

/// "Nguyễn Văn Đạt" -> "Nguyen Van Dat". Assumes precomposed (NFC) input.
String stripDiacritics(String s) => s.split('').map((c) => _fold[c] ?? c).join();

/// Normalised form for comparing bank account names with the CCCD name.
String normalizeName(String s) =>
    stripDiacritics(s).toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
