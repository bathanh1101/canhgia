/// Pure clipboard gate: finds the first URL whose host belongs to a partner merchant and
/// remembers it, so the same link is offered once (dedupe by last seen string).
class ClipboardLinkDetector {
  ClipboardLinkDetector(Iterable<String> domains) : _hosts = {for (final d in domains) d.toLowerCase(), ..._shortHosts};

  /// Share/short hosts not always listed in merchant domains; resolve-url has the final say.
  static const _shortHosts = {'shope.ee', 'shp.ee', 'lzd.co', 'vt.tiktok.com', 'vm.tiktok.com'};
  static final _url = RegExp(r'https?://[^\s]+', caseSensitive: false);

  final Set<String> _hosts;
  String? _last;

  bool _supported(String host) {
    final h = host.toLowerCase();
    return _hosts.any((d) => h == d || h.endsWith('.$d'));
  }

  /// First supported URL inside [text], or null.
  String? extract(String? text) {
    if (text == null || text.isEmpty) return null;
    for (final m in _url.allMatches(text)) {
      final u = Uri.tryParse(m[0]!);
      if (u != null && u.host.isNotEmpty && _supported(u.host)) return m[0];
    }
    return null;
  }

  /// [extract] that returns each distinct link once.
  String? acceptNew(String? text) {
    final link = extract(text);
    if (link == null || link == _last) return null;
    _last = link;
    return link;
  }
}
