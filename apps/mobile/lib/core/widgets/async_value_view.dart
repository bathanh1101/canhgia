import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/postgrest_error_mapper.dart';
import 'app_button.dart';

/// loading / error(+retry) / data wrapper for any AsyncValue.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({super.key, required this.value, required this.data, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
        skipLoadingOnRefresh: true,
        data: data,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mapErrorMessage(e), textAlign: TextAlign.center),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  AppButton(label: 'Thử lại', onPressed: onRetry, kind: AppButtonKind.outline, expand: false),
                ],
              ],
            ),
          ),
        ),
      );
}
