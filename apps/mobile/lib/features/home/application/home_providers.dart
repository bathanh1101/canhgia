import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/merchants_provider.dart';
import '../../link/application/link_providers.dart';
import '../data/link_models.dart';
import 'clipboard_link_detector.dart';

/// Detected/pasted link and what resolve-url said about it.
class LinkCard {
  const LinkCard({required this.url, required this.resolved});
  final String url;
  final ResolvedUrl resolved;
}

/// iOS shows no paste banner when hasStrings is false; getData only when it is true.
final clipboardReaderProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    if (!await Clipboard.hasStrings()) return null;
    return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
  },
);

/// Home link card. `AsyncData(null)` = nothing to show. Never auto-creates a link.
class ClipboardLinkNotifier extends AsyncNotifier<LinkCard?> {
  ClipboardLinkDetector? _detector;
  int _domainsKey = 0;

  @override
  LinkCard? build() => null;

  /// Called on home start and app resume. Unsupported/failed links are ignored silently.
  Future<void> checkClipboard() async {
    try {
      final merchants = await ref.read(merchantsProvider.future);
      final domains = [for (final m in merchants) ...m.domains];
      final key = Object.hashAll(domains);
      if (_detector == null || key != _domainsKey) {
        _detector = ClipboardLinkDetector(domains);
        _domainsKey = key;
      }
      final link = _detector!.acceptNew(await ref.read(clipboardReaderProvider)());
      if (link == null) return;
      state = const AsyncLoading();
      state = AsyncData(LinkCard(url: link, resolved: await ref.read(linkRepositoryProvider).resolve(link)));
    } on Object {
      state = const AsyncData(null);
    }
  }

  /// Manual paste field: errors propagate so the UI can show the mapped message.
  Future<void> submit(String url) async {
    final resolved = await ref.read(linkRepositoryProvider).resolve(url);
    state = AsyncData(LinkCard(url: url.trim(), resolved: resolved));
  }

  void dismiss() => state = const AsyncData(null);
}

final clipboardLinkProvider = AsyncNotifierProvider<ClipboardLinkNotifier, LinkCard?>(ClipboardLinkNotifier.new);
