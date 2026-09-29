import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Always-visible fallback to the clipboard detector: paste/type a link and submit.
class PasteLinkField extends StatefulWidget {
  const PasteLinkField({super.key, required this.onSubmit, this.busy = false});

  final Future<void> Function(String url) onSubmit;
  final bool busy;

  @override
  State<PasteLinkField> createState() => _PasteLinkFieldState();
}

class _PasteLinkFieldState extends State<PasteLinkField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final t = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (t != null) setState(() => _ctrl.text = t.trim());
  }

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isNotEmpty && !widget.busy) widget.onSubmit(v);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Dán link để nhận hoàn tiền', style: AppText.title),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Dán link Shopee, Lazada, TikTok…',
            filled: true,
            fillColor: AppColors.surface,
            prefixIcon: const Icon(Icons.link),
            suffixIcon: widget.busy
                ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    TextButton(onPressed: _paste, child: const Text('Dán')),
                    IconButton(tooltip: 'Tạo link', onPressed: _submit, icon: const Icon(Icons.arrow_forward, color: AppColors.primary)),
                  ]),
          ),
        ),
      ]);
}
