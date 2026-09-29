import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum PillTone { pending, success, danger, info }

/// Small coloured label. Prefer the named constructors so 05/06 stay consistent.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, this.tone, {super.key});

  /// Order/withdrawal/KYC status codes -> pill. Unknown statuses render as info.
  factory StatusPill.forStatus(String status, {Key? key}) => switch (status) {
        'pending' || 'processing' => StatusPill('Chờ duyệt', PillTone.pending, key: key),
        'credited' || 'approved' || 'paid' || 'verified' => StatusPill('Đã duyệt', PillTone.success, key: key),
        'cancelled' || 'reversed' || 'rejected' => StatusPill('Bị hủy', PillTone.danger, key: key),
        'checking' || 'submitted' => StatusPill('Đang kiểm tra', PillTone.info, key: key),
        _ => StatusPill(status, PillTone.info, key: key),
      };

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      PillTone.pending => (AppColors.warning, AppColors.warningTint),
      PillTone.success => (AppColors.primary, AppColors.primaryTint),
      PillTone.danger => (AppColors.error, AppColors.errorTint),
      PillTone.info => (AppColors.info, AppColors.infoTint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
