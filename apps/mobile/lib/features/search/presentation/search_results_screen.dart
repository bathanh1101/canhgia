import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../core/providers/merchants_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../application/search_providers.dart';
import '../data/search_repository.dart';
import 'widgets/offer_hit_tile.dart';

/// Screen 19: grouped results with merchant filter (datafeed merchants), sort chips and paging.
class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({super.key, required this.args});

  final SearchArgs args;

  @override
  ConsumerState<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  final _scroll = ScrollController();
  late final _query = TextEditingController(text: widget.args.q);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        ref.read(searchResultsProvider(widget.args).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  void _go({String? q, String? merchant, String? sort}) => context.replace(searchResultsLocation(
        q ?? widget.args.q,
        merchant: merchant ?? widget.args.merchant,
        sort: sort ?? widget.args.sort,
      ));

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final results = ref.watch(searchResultsProvider(a));
    final merchants = ref.watch(merchantsProvider).value?.where((m) => m.datafeedEnabled).toList() ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => v.trim().isEmpty ? null : _go(q: v.trim()),
          decoration: const InputDecoration(border: InputBorder.none, hintText: 'Tìm sản phẩm…'),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(children: [
            FilterChipBar<String>(
              options: {'': 'Tất cả sàn', for (final m in merchants) m.id: m.name},
              selected: a.merchant,
              onSelected: (m) => _go(merchant: m),
            ),
            const SizedBox(height: 4),
            FilterChipBar<String>(options: searchSorts, selected: a.sort, onSelected: (s) => _go(sort: s)),
          ]),
        ),
        Expanded(
          child: AsyncValueView(
            value: results,
            onRetry: () => ref.invalidate(searchResultsProvider(a)),
            data: (paged) => paged.items.isEmpty
                ? const EmptyState(message: 'Không tìm thấy sản phẩm phù hợp. Thử từ khóa khác nhé.', icon: Icons.search_off)
                : ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: paged.items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => i < paged.items.length ? OfferHitTile(hit: paged.items[i]) : _footer(paged),
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _footer(PagedOffers p) {
    if (p.loadingMore) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
    if (p.loadMoreFailed) {
      return AppButton(
        label: 'Tải thêm thất bại · Thử lại',
        kind: AppButtonKind.outline,
        onPressed: ref.read(searchResultsProvider(widget.args).notifier).loadMore,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Center(child: Text(p.hasMore ? '' : 'Đã hiển thị tất cả kết quả', style: AppText.caption)),
    );
  }
}
