import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/format_vnd.dart';
import '../../../../core/widgets/app_button.dart';
import '../../data/withdrawal.dart';

/// Shown in place of the form once `request_withdrawal` succeeded.
class WithdrawResultView extends StatelessWidget {
  const WithdrawResultView({super.key, required this.result, required this.amount, required this.eta});

  final WithdrawalResult result;
  final int amount;
  final String eta;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primaryTintStrong,
            child: Icon(Icons.check, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('Đã gửi yêu cầu rút tiền', style: AppText.h2),
          const SizedBox(height: 8),
          Text(formatVnd(amount), style: AppText.h1.copyWith(color: AppColors.primary)),
          const SizedBox(height: 8),
          Text('Trạng thái: Chờ xử lý · $eta', style: AppText.body, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          AppButton(label: 'Xem lịch sử rút tiền', kind: AppButtonKind.outline, onPressed: () => context.pushReplacement('${RoutePaths.withdraw}/history')),
          const SizedBox(height: 8),
          AppButton(label: 'Xong', onPressed: () => context.pop()),
        ]),
      );
}
