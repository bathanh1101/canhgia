import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/providers/auth_session_provider.dart';
import '../../../core/providers/merchants_provider.dart';
import '../../../core/utils/format_date.dart';
import '../../../core/utils/format_vnd.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../../kyc/application/kyc_providers.dart';
import '../../kyc/presentation/widgets/photo_slot.dart';
import '../../withdraw/application/withdraw_validation.dart';
import '../application/missing_order_providers.dart';
import '../application/missing_order_validation.dart';
import 'widgets/recent_reports.dart';

/// Screen 14 - report a purchase that never showed up (order code, date, value, <= 3 screenshots).
class MissingOrderScreen extends ConsumerStatefulWidget {
  const MissingOrderScreen({super.key, this.today});

  final DateTime? today;

  @override
  ConsumerState<MissingOrderScreen> createState() => _MissingOrderScreenState();
}

class _MissingOrderScreenState extends ConsumerState<MissingOrderScreen> {
  final _code = TextEditingController();
  final _value = TextEditingController();

  DateTime get _today => widget.today ?? DateTime.now();

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final t = _today;
    final d = await showDatePicker(
      context: context,
      initialDate: t.subtract(const Duration(days: 1)),
      firstDate: t.subtract(const Duration(days: 60)),
      lastDate: t.subtract(const Duration(days: 1)),
    );
    if (d != null && mounted) ref.read(missingOrderFormProvider.notifier).setDate(d);
  }

  Future<void> _pickPhotos() async {
    final messenger = ScaffoldMessenger.of(context);
    final have = ref.read(missingOrderFormProvider).photos.length;
    if (have >= maxMissingOrderPhotos) return;
    try {
      final more = await ref.read(photoPickerProvider).pickMany(maxMissingOrderPhotos - have);
      if (!mounted) return;
      ref.read(missingOrderFormProvider.notifier).addPhotos(more);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(missingOrderErrorMessage(e))));
    }
  }

  Future<void> _submit() async {
    final uid = ref.read(currentUserIdProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (uid == null) return;
    try {
      final code = await ref.read(missingOrderFormProvider.notifier).submit(uid, today: _today);
      if (code == null || !mounted) return;
      _code.clear();
      _value.clear();
      messenger.showSnackBar(SnackBar(content: Text('Đã gửi yêu cầu $code. Chúng tôi sẽ đối soát với sàn.')));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(missingOrderErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(missingOrderFormProvider);
    final ctl = ref.read(missingOrderFormProvider.notifier);
    final merchants = ref.watch(merchantsProvider).value ?? const [];
    return Scaffold(
      appBar: const AppTopBar(title: 'Báo đơn bị thiếu'),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.infoTint, borderRadius: BorderRadius.circular(14)),
              child: const Text('Đơn chưa hiển thị sau 24 giờ? Gửi thông tin để CanhGia đối soát với sàn và bù hoàn tiền cho bạn.'),
            ),
            const SizedBox(height: 16),
            Text('Sàn mua hàng', style: AppText.label),
            const SizedBox(height: 6),
            FilterChipBar<String>(
              options: {for (final m in merchants) m.id: m.name},
              selected: f.merchantId ?? '',
              onSelected: ctl.setMerchant,
            ),
            const SizedBox(height: 12),
            Text('Mã đơn hàng', style: AppText.label),
            const SizedBox(height: 6),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(40)],
              onChanged: ctl.setOrderCode,
            ),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ngày mua', style: AppText.label),
                  const SizedBox(height: 6),
                  OutlinedButton(
                    onPressed: _pickDate,
                    child: Text(f.purchasedOn == null ? 'Chọn ngày' : formatDate(f.purchasedOn!)),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Giá trị đơn', style: AppText.label),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _value,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    decoration: InputDecoration(suffixText: 'đ', helperText: f.valueVnd > 0 ? formatVnd(f.valueVnd) : null),
                    onChanged: (t) => ctl.setValue(parseAmount(t)),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Text('Ảnh chụp chi tiết đơn hàng (tối đa $maxMissingOrderPhotos, JPG/PNG)', style: AppText.label),
            const SizedBox(height: 6),
            Row(children: [
              for (var i = 0; i < f.photos.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PhotoSlot(label: '', photo: f.photos[i], onTap: () => ctl.removePhoto(i)),
                  ),
                ),
              if (f.photos.length < maxMissingOrderPhotos)
                Expanded(child: PhotoSlot(label: 'Tải ảnh lên', photo: null, onTap: _pickPhotos)),
              for (var i = f.photos.length + 1; i < maxMissingOrderPhotos; i++) const Expanded(child: SizedBox()),
            ]),
            if (f.photos.isNotEmpty) Text('Chạm vào ảnh để bỏ.', style: AppText.caption),
            const SizedBox(height: 20),
            const RecentReports(),
          ]),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AppButton(label: 'Gửi yêu cầu', loading: f.submitting, onPressed: _submit),
          ),
        ),
      ]),
    );
  }
}
