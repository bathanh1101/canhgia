import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/async_value_view.dart';
import '../application/search_providers.dart';
import '../data/search_repository.dart';
import 'widgets/offer_hit_tile.dart';

/// Screen 18: query box, recent searches (max 10) and live suggestions (debounced 300ms).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  var _typed = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) return setState(() => _typed = '');
    _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => _typed = v.trim()));
  }

  Future<void> _submit(String q) async {
    final t = q.trim();
    if (t.isEmpty) return;
    await ref.read(recentSearchesProvider.notifier).add(t);
    if (mounted) context.push(searchResultsLocation(t));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: _submit,
            decoration: const InputDecoration(hintText: 'Tìm sản phẩm trên Shopee, Lazada…', border: InputBorder.none),
          ),
          actions: [
            if (_ctrl.text.isNotEmpty)
              IconButton(
                tooltip: 'Xóa',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _ctrl.clear();
                  _typed = '';
                }),
              ),
          ],
        ),
        body: _typed.isEmpty ? _recent() : _suggestions(),
      );

  Widget _recent() {
    final recent = ref.watch(recentSearchesProvider);
    if (recent.isEmpty) {
      return Center(child: Text('Nhập tên sản phẩm để so sánh giá và nhận hoàn tiền', style: AppText.body, textAlign: TextAlign.center));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: Text('Tìm kiếm gần đây', style: AppText.title)),
        TextButton(onPressed: ref.read(recentSearchesProvider.notifier).clear, child: const Text('Xóa')),
      ]),
      for (final q in recent)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history, color: AppColors.textMuted),
          title: Text(q),
          trailing: IconButton(
            tooltip: 'Xóa "$q"',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => ref.read(recentSearchesProvider.notifier).remove(q),
          ),
          onTap: () {
            _ctrl.text = q;
            _submit(q);
          },
        ),
    ]);
  }

  Widget _suggestions() => AsyncValueView(
        value: ref.watch(searchSuggestionsProvider(_typed)),
        onRetry: () => ref.invalidate(searchSuggestionsProvider(_typed)),
        data: (hits) => ListView(padding: const EdgeInsets.all(16), children: [
          ListTile(
            leading: const Icon(Icons.search, color: AppColors.primary),
            title: Text('Tìm "$_typed"'),
            onTap: () => _submit(_typed),
          ),
          for (final h in hits)
            Padding(padding: const EdgeInsets.only(top: 8), child: OfferHitTile(hit: h)),
        ]),
      );
}
