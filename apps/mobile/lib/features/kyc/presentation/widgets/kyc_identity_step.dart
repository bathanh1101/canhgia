import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/providers/auth_session_provider.dart';
import '../../../../core/supabase/postgrest_error_mapper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../application/kyc_logic.dart';
import '../../application/kyc_providers.dart';
import '../../data/kyc_repository.dart';
import '../../data/photo.dart';
import 'photo_slot.dart';

/// Step 1: CCCD photos + name + number -> `submit_kyc`; then "Đang chờ duyệt".
class KycIdentityStep extends ConsumerStatefulWidget {
  const KycIdentityStep({super.key, required this.profile});

  final KycProfile? profile;

  @override
  ConsumerState<KycIdentityStep> createState() => _KycIdentityStepState();
}

class _KycIdentityStepState extends ConsumerState<KycIdentityStep> {
  final _name = TextEditingController();
  final _id = TextEditingController();
  PickedPhoto? _front;
  PickedPhoto? _back;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().length >= 2 && isValidIdNumber(_id.text) && _front != null && _back != null;

  Future<void> _pick(bool front) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final p = await ref.read(photoPickerProvider).pickOne();
      if (p != null && mounted) setState(() => front ? _front = p : _back = p);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(e))));
    }
  }

  Future<void> _submit() async {
    final uid = ref.read(currentUserIdProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (uid == null || _busy || !_valid) return;
    setState(() => _busy = true);
    try {
      await ref.read(kycRepositoryProvider).submit(
            uid: uid,
            fullName: _name.text.trim(),
            idNumber: _id.text.trim(),
            front: _front!,
            back: _back!,
          );
      ref.invalidate(kycProfileProvider);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    if (p != null && p.isPending) {
      return const _Notice(
        icon: Icons.hourglass_top,
        title: 'Đang chờ duyệt',
        body: 'Hồ sơ định danh của bạn đang được xem xét, thường trong 1 ngày làm việc. Chúng tôi sẽ thông báo khi có kết quả.',
        tint: AppColors.warningTint,
        color: AppColors.warning,
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (p != null && p.isRejected)
        _Notice(
          icon: Icons.error_outline,
          title: 'Hồ sơ chưa được duyệt',
          body: '${p.rejectReason ?? 'Thông tin chưa hợp lệ.'} Vui lòng gửi lại.',
          tint: AppColors.errorTint,
          color: AppColors.error,
        ),
      const SizedBox(height: 12),
      Text('Họ và tên (theo CCCD)', style: AppText.label),
      const SizedBox(height: 6),
      TextField(controller: _name, textCapitalization: TextCapitalization.words, onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      Text('Số CCCD / CMND', style: AppText.label),
      const SizedBox(height: 6),
      TextField(
        controller: _id,
        keyboardType: TextInputType.number,
        maxLength: 12,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(counterText: ''),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: PhotoSlot(label: 'Mặt trước', photo: _front, onTap: () => _pick(true))),
        const SizedBox(width: 12),
        Expanded(child: PhotoSlot(label: 'Mặt sau', photo: _back, onTap: () => _pick(false))),
      ]),
      const SizedBox(height: 8),
      Text('Ảnh chỉ dùng để xác minh và được lưu riêng tư. Số CCCD không được lưu nguyên vẹn.', style: AppText.caption),
      const SizedBox(height: 16),
      AppButton(label: 'Gửi xác thực', loading: _busy, onPressed: _valid ? _submit : null),
    ]);
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body, required this.tint, required this.color});
  final IconData icon;
  final String title;
  final String body;
  final Color tint;
  final Color color;

  @override
  Widget build(BuildContext context) => AppCard(
        color: tint,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.title.copyWith(color: color)),
              const SizedBox(height: 4),
              Text(body, style: AppText.body),
            ]),
          ),
        ]),
      );
}
