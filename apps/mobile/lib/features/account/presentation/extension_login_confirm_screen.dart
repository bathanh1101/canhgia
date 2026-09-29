import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/utils/user_agent_summary.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../application/account_providers.dart';
import '../data/account_repository.dart';

/// Explicit confirmation step (QRLjacking defence): nothing is approved until
/// the user taps "Xác nhận đăng nhập".
class ExtensionLoginConfirmScreen extends ConsumerStatefulWidget {
  const ExtensionLoginConfirmScreen({super.key, required this.code});

  final String? code;

  @override
  ConsumerState<ExtensionLoginConfirmScreen> createState() => _ExtensionLoginConfirmScreenState();
}

class _ExtensionLoginConfirmScreenState extends ConsumerState<ExtensionLoginConfirmScreen> {
  ExtensionLoginRequest? _request;
  String? _error;
  var _approving = false;
  var _done = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final code = widget.code;
    if (!AccountRepository.isValidCode(code)) {
      setState(() => _error = errorMessagesVi['code_invalid']);
      return;
    }
    try {
      final r = await ref.read(accountRepositoryProvider).getExtensionLoginRequest(code!);
      if (!mounted) return;
      setState(() => _request = r);
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
    } on Object catch (e) {
      if (mounted) setState(() => _error = _expiredOr(e));
    }
  }

  String _expiredOr(Object e) =>
      errorCodeOf(e) == 'code_invalid' ? 'Mã hết hạn, tạo mã mới trên tiện ích.' : mapErrorMessage(e);

  Future<void> _approve() async {
    setState(() => _approving = true);
    try {
      await ref.read(accountRepositoryProvider).approveExtensionLogin(widget.code!);
      if (mounted) setState(() => _done = true);
    } on Object catch (e) {
      if (mounted) setState(() => _error = _expiredOr(e));
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  String _remaining(DateTime expiresAt) {
    final s = expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 86400);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final r = _request;
    final expired = r != null && !r.expiresAt.isAfter(DateTime.now());
    return Scaffold(
      appBar: const AppTopBar(title: 'Đăng nhập tiện ích Chrome'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _done
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle, size: 64, color: AppColors.primary),
                const SizedBox(height: 12),
                const Text('Đã đăng nhập tiện ích', style: AppText.h2),
                const SizedBox(height: 24),
                AppButton(label: 'Xong', onPressed: () => context.pop()),
              ])
            : _error != null
                ? Center(child: Text(_error!, textAlign: TextAlign.center, style: AppText.body))
                : r == null
                    ? const Center(child: CircularProgressIndicator())
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AppCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(summarizeUserAgent(r.userAgent), style: AppText.title),
                            const SizedBox(height: 4),
                            Text('IP ${r.ipMasked} · hết hạn sau ${_remaining(r.expiresAt)}', style: AppText.caption),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        AppCard(
                          color: AppColors.warningTint,
                          child: const Text(
                            'Chỉ xác nhận nếu chính bạn vừa mở tiện ích CanhGia trên máy tính này. Không quét mã do người khác gửi.',
                            style: AppText.body,
                          ),
                        ),
                        const Spacer(),
                        AppButton(
                          label: expired ? 'Mã đã hết hạn' : 'Xác nhận đăng nhập',
                          loading: _approving,
                          onPressed: expired ? null : _approve,
                        ),
                      ]),
      ),
    );
  }
}
