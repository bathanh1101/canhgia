import 'package:canhgia_mobile/features/home/application/clipboard_link_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ClipboardLinkDetector d() => ClipboardLinkDetector(['shopee.vn', 'lazada.vn']);

  test('finds a supported url inside surrounding text', () {
    expect(d().extract('Xem nè https://shopee.vn/product/1?x=2 hay quá'), 'https://shopee.vn/product/1?x=2');
    expect(d().extract('https://s.shopee.vn/AbC'), 'https://s.shopee.vn/AbC');
    expect(d().extract('https://shope.ee/xyz'), 'https://shope.ee/xyz');
  });

  test('ignores other hosts, lookalikes and hosts that only mention a domain in the path/query', () {
    for (final t in [
      null,
      '',
      'không có link',
      'https://google.com/search?q=shopee.vn',
      'https://evil.com/shopee.vn',
      'https://notshopee.vn/x',
      'https://shopee.vn.evil.com/x',
    ]) {
      expect(d().extract(t), isNull, reason: '$t');
    }
  });

  test('offers each distinct link once (dedupe by last seen)', () {
    final det = d();
    expect(det.acceptNew('https://shopee.vn/a'), 'https://shopee.vn/a');
    expect(det.acceptNew('https://shopee.vn/a'), isNull);
    expect(det.acceptNew('https://lazada.vn/b'), 'https://lazada.vn/b');
    expect(det.acceptNew('https://shopee.vn/a'), 'https://shopee.vn/a');
  });
}
