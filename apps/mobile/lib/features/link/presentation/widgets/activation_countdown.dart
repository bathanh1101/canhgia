import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../home/data/link_models.dart';
import '../../application/link_providers.dart';

/// "Còn 23:59:07 để mua" ticking once per second; "Đã hết thời gian" at zero.
class ActivationCountdown extends StatefulWidget {
  const ActivationCountdown({super.key, required this.link, this.now = DateTime.now});

  final CreatedLink link;
  final DateTime Function() now;

  @override
  State<ActivationCountdown> createState() => _ActivationCountdownState();
}

class _ActivationCountdownState extends State<ActivationCountdown> {
  Timer? _timer;
  late Duration _left = activationRemaining(widget.link, widget.now());

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = activationRemaining(widget.link, widget.now());
      setState(() => _left = left);
      if (left == Duration.zero) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          _left == Duration.zero ? 'Đã hết thời gian mua' : 'Còn ${formatCountdown(_left)} để mua',
          style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w800),
        ),
      );
}
