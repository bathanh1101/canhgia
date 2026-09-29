import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';

const _maxTargetVnd = 1000000000000;

/// "5.900.000" / "5900000đ" -> 5900000; null when empty, zero or absurdly large.
int? parseVndInput(String raw) {
  final v = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
  return v == null || v <= 0 || v > _maxTargetVnd ? null : v;
}

/// Bottom sheet asking for the alert target (giá bán, chưa trừ hoàn tiền). Returns the VND target, or null if dismissed.
Future<int?> showTargetPriceSheet(BuildContext context, {required int initial}) => showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TargetSheet(initial: initial),
    );

class _TargetSheet extends StatefulWidget {
  const _TargetSheet({required this.initial});
  final int initial;

  @override
  State<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends State<_TargetSheet> {
  late final _ctrl = TextEditingController(text: '${widget.initial}');
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseVndInput(_ctrl.text);
    if (v == null) return setState(() => _error = 'Nhập mức giá lớn hơn 0');
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Báo khi giá bán dưới', style: AppText.title),
          const SizedBox(height: 4),
          Text('Nhận thông báo đẩy khi bất kỳ sàn nào đạt mức giá này (đã tính hoàn tiền).', style: AppText.caption),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(suffixText: 'đ', errorText: _error, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          AppButton(label: 'Lưu theo dõi giá', onPressed: _save),
        ]),
      );
}
