import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/route_paths.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../data/account_repository.dart';

/// Scans the QR shown by the Chrome extension (`canhgia-ext:<uuid>`). Scanning
/// alone approves nothing: it only opens the confirm screen.
class ExtensionLoginScanScreen extends StatefulWidget {
  const ExtensionLoginScanScreen({super.key});

  @override
  State<ExtensionLoginScanScreen> createState() => _ExtensionLoginScanScreenState();
}

class _ExtensionLoginScanScreenState extends State<ExtensionLoginScanScreen> {
  var _handled = false;
  var _invalid = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final b in capture.barcodes) {
      final code = AccountRepository.parseExtensionQr(b.rawValue);
      if (code != null) {
        _handled = true;
        context.pushReplacement('${RoutePaths.accountExtensionConfirm}?code=$code');
        return;
      }
    }
    if (!_invalid) setState(() => _invalid = true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AppTopBar(title: 'Đăng nhập tiện ích Chrome'),
        body: Column(children: [
          Expanded(
            child: MobileScanner(
              onDetect: _onDetect,
              errorBuilder: (_, _) => const Center(child: Text('Không mở được camera. Hãy cấp quyền camera cho CanhGia.')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _invalid
                  ? 'Mã QR này không phải của tiện ích CanhGia.'
                  : 'Mở tiện ích CanhGia trên Chrome, chọn "Đăng nhập bằng mã QR" rồi quét mã hiển thị.',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ),
        ]),
      );
}
