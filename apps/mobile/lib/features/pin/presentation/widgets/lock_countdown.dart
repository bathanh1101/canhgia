import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../application/pin_state.dart';

/// "Tạm khóa · thử lại sau 14:59"; calls [onDone] when the window elapses.
class LockCountdown extends StatefulWidget {
  const LockCountdown({super.key, required this.until, required this.onDone, this.clock = DateTime.now});

  final DateTime until;
  final VoidCallback onDone;
  final DateTime Function() clock;

  @override
  State<LockCountdown> createState() => _LockCountdownState();
}

class _LockCountdownState extends State<LockCountdown> {
  Timer? _timer;
  late Duration _left = lockRemaining(widget.until, widget.clock());

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (_left == Duration.zero) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
  }

  void _tick() {
    final left = lockRemaining(widget.until, widget.clock());
    if (!mounted) return;
    setState(() => _left = left);
    if (left == Duration.zero) {
      _timer?.cancel();
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        'Tạm khóa đến ${_hhmm(widget.until)} · thử lại sau ${formatCountdown(_left)}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
      );

  static String _hhmm(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
