import 'package:canhgia_mobile/core/providers/merchants_provider.dart';
import 'package:canhgia_mobile/features/home/application/home_providers.dart';
import 'package:canhgia_mobile/features/home/data/link_models.dart';
import 'package:canhgia_mobile/features/home/data/link_repository.dart';
import 'package:canhgia_mobile/features/link/application/link_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../search/test_support.dart';

class _MockLinks extends Mock implements LinkRepository {}

ResolvedUrl _resolved() => ResolvedUrl.fromJson({'merchant_id': 'shopee', 'datafeed_enabled': true});

void main() {
  late _MockLinks links;
  late String? clip;
  late ProviderContainer c;

  setUp(() {
    links = _MockLinks();
    clip = null;
    c = ProviderContainer(retry: (_, _) => null, overrides: [
      merchantsProvider.overrideWith((_) async => [shopee]),
      linkRepositoryProvider.overrideWithValue(links),
      clipboardReaderProvider.overrideWithValue(() async => clip),
    ]);
    addTearDown(c.dispose);
  });

  test('shows a card once per copied link; dismiss keeps it hidden until a new link', () async {
    when(() => links.resolve(any())).thenAnswer((_) async => _resolved());
    final n = c.read(clipboardLinkProvider.notifier);
    clip = 'https://shopee.vn/p/1';
    await n.checkClipboard();
    expect(c.read(clipboardLinkProvider).value!.url, 'https://shopee.vn/p/1');
    n.dismiss();
    await n.checkClipboard();
    expect(c.read(clipboardLinkProvider).value, isNull);
    verify(() => links.resolve(any())).called(1);
    clip = 'https://shopee.vn/p/2';
    await n.checkClipboard();
    expect(c.read(clipboardLinkProvider).value!.url, 'https://shopee.vn/p/2');
  });

  test('foreign clipboard content never reaches resolve-url', () async {
    clip = 'mật khẩu wifi: 12345678';
    await c.read(clipboardLinkProvider.notifier).checkClipboard();
    clip = 'https://example.com/x';
    await c.read(clipboardLinkProvider.notifier).checkClipboard();
    verifyNever(() => links.resolve(any()));
  });

  test('resolve failure on a clipboard link is swallowed; manual submit surfaces the error', () async {
    when(() => links.resolve(any())).thenThrow(Exception('unsupported_url'));
    clip = 'https://shopee.vn/p/3';
    final n = c.read(clipboardLinkProvider.notifier);
    await n.checkClipboard();
    expect(c.read(clipboardLinkProvider).value, isNull);
    await expectLater(n.submit('https://shopee.vn/p/3'), throwsException);
  });
}
