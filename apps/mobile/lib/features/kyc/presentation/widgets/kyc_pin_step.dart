import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/widgets/app_button.dart';

/// Step 3: create the withdrawal PIN via `/pin?mode=create`.
class KycPinStep extends ConsumerWidget {
  const KycPinStep({super.key, required this.hasPin});

  final bool hasPin;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(children: [
        const SizedBox(height: 24),
        Icon(hasPin ? Icons.check_circle : Icons.pin_outlined, size: 64, color: AppColors.primary),
        const SizedBox(height: 12),
        Text(hasPin ? 'Hoàn tất thiết lập rút tiền' : 'Tạo mã PIN rút tiền', style: AppText.h2),
        const SizedBox(height: 8),
        Text(
          hasPin
              ? 'Bạn đã sẵn sàng rút tiền về tài khoản ngân hàng.'
              : 'Mã PIN 6 số bảo vệ mỗi lần rút tiền. Đổi PIN hoặc thêm ngân hàng sẽ tạm khóa rút tiền 24 giờ để an toàn.',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
        const SizedBox(height: 24),
        AppButton(
          label: hasPin ? 'Xong' : 'Tạo mã PIN',
          onPressed: () async {
            if (hasPin) {
              context.pop();
              return;
            }
            final r = await context.push<String>(RoutePaths.pinFor('create'));
            if (r != null) ref.invalidate(profileProvider);
          },
        ),
      ]);
}
