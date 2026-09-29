import 'package:canhgia_mobile/core/utils/format_date.dart';
import 'package:canhgia_mobile/core/utils/format_vnd.dart';
import 'package:canhgia_mobile/core/utils/user_agent_summary.dart';
import 'package:canhgia_mobile/core/utils/vn_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatVnd groups thousands with dots', () {
    expect(formatVnd(0), '0đ');
    expect(formatVnd(999), '999đ');
    expect(formatVnd(1250000), '1.250.000đ');
    expect(formatVnd(100000), '100.000đ');
    expect(formatVnd(-50000), '-50.000đ');
  });

  test('formatVndCompact', () {
    expect(formatVndCompact(4860000), '4,86tr');
    expect(formatVndCompact(250000), '250K');
    expect(formatVndCompact(0), '0');
  });

  test('formatDayMonth / formatDate pad', () {
    final d = DateTime(2026, 9, 5, 7, 3);
    expect(formatDayMonth(d), '05/09');
    expect(formatDate(d), '05/09/2026');
    expect(formatDateTime(d), '05/09/2026 07:03');
  });

  test('stripDiacritics and normalizeName', () {
    expect(stripDiacritics('Nguyễn Văn Đạt'), 'Nguyen Van Dat');
    expect(normalizeName('  nguyễn   văn  minh '), 'NGUYEN VAN MINH');
  });

  group('summarizeUserAgent', () {
    test('Chrome on Windows', () {
      const ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';
      expect(summarizeUserAgent(ua), 'Chrome trên Windows');
    });
    test('Edge is not reported as Chrome', () {
      const ua = 'Mozilla/5.0 (Windows NT 10.0) Chrome/126.0 Safari/537.36 Edg/126.0';
      expect(summarizeUserAgent(ua), 'Edge trên Windows');
    });
    test('Firefox on Linux, macOS Chrome', () {
      expect(summarizeUserAgent('Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0'), 'Firefox trên Linux');
      expect(summarizeUserAgent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/126.0 Safari/537.36'), 'Chrome trên macOS');
    });
    test('empty / unknown', () {
      expect(summarizeUserAgent(null), 'Thiết bị không xác định');
      expect(summarizeUserAgent('curl/8'), 'Thiết bị không xác định');
    });
  });
}
