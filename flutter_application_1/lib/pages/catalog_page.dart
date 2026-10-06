import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../models/product.dart';
import '../services/commerce_service.dart';
import '../widgets/live_page.dart';
import '../widgets/product_tile.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({
    super.key,
    required this.service,
    this.savedOnly = false,
    this.search = false,
  });
  final CommerceService service;
  final bool savedOnly, search;
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  String query = '';
  BrowseMemory? memory;
  bool restored = false;
  String get memoryKey => widget.savedOnly ? 'saved' : 'catalog';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    memory = BrowseMemory.of(context);
    if (!restored) {
      restored = true;
      query = memory?.values['$memoryKey.query'] as String? ?? '';
      selectedCategory = memory?.values['$memoryKey.category'] as String?;
      searchController.text = query;
    }
  }

  String? selectedCategory;
  final searchController = TextEditingController();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void remember() {
    memory?.values['$memoryKey.query'] = query;
    memory?.values['$memoryKey.category'] = selectedCategory;
  }

  final fallbackBucket = PageStorageBucket();
  final busy = <int>{};
  late final pager = widget.service.productPager();
  Set<int> saved = {};

  /// Favorites are one small list; the catalogue starts with its first page.
  Future<List<Product>> load() async {
    if (widget.savedOnly) {
      final items = await widget.service.products(saved: true);
      saved = items.map((p) => p.id).toSet();
      return items;
    }
    final results = await Future.wait([
      widget.service.products(saved: true),
      pager.refresh(),
    ]);
    saved = results[0].map((p) => p.id).toSet();
    return results[1];
  }

  /// Scrolling loads automatically until a page fails; after that only the
  /// button retries, so errors and 429s never turn into a request loop.
  bool autoLoad = true;
  Future<void> loadMore({bool manual = false}) async {
    if (widget.savedOnly || !pager.hasMore || pager.loading) return;
    if (!manual && !autoLoad) return;
    setState(() => autoLoad = true);
    try {
      await pager.more();
    } catch (e) {
      autoLoad = false;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AuthController.message(e))));
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> toggle(
    Product p,
    bool wasSaved,
    Future<void> Function() reload,
  ) async {
    if (busy.contains(p.id)) return;
    setState(() => busy.add(p.id));
    try {
      await widget.service.favorite(p.id, !wasSaved);
      if (widget.savedOnly) {
        await reload();
      } else if (mounted) {
        // Only the heart changed; refetching every loaded page is wasteful.
        setState(() {
          if (wasSaved) {
            saved.remove(p.id);
          } else {
            saved.add(p.id);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AuthController.message(e))));
      }
    } finally {
      if (mounted) setState(() => busy.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) => LiveScaffold(
    title: widget.savedOnly
        ? 'Produse salvate'
        : widget.search
        ? 'Caută oferte'
        : 'Wasteless',
    index: widget.savedOnly
        ? 2
        : widget.search
        ? 1
        : 0,
    body: LoadPanel(
      load: load,
      builder: (data, reload) {
        // Load-more appends to the pager after this snapshot was taken.
        final all = widget.savedOnly ? data : pager.items;
        final canLoadMore = !widget.savedOnly && pager.hasMore;
        final products = all
            .where(
              (p) =>
                  p.name.toLowerCase().contains(query.toLowerCase()) &&
                  (selectedCategory == null || p.category == selectedCategory),
            )
            .toList();
        return Column(
          children: [
            if (!widget.savedOnly &&
                !widget.search &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.3 &&
                MediaQuery.sizeOf(context).height >= 700)
              const _CatalogHero(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Caută un produs',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Șterge căutarea',
                              onPressed: () {
                                searchController.clear();
                                setState(() => query = '');
                                remember();
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: (v) {
                      setState(() => query = v);
                      remember();
                    },
                  ),
                ),
              ),
            ),
            if (all.any((p) => p.category?.isNotEmpty == true))
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (final category in <String?>[
                      null,
                      ...all
                          .map((p) => p.category)
                          .whereType<String>()
                          .where((c) => c.isNotEmpty)
                          .toSet(),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category ?? 'Toate'),
                          selected: selectedCategory == category,
                          onSelected: (_) {
                            setState(() => selectedCategory = category);
                            remember();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: all.isEmpty
                  ? EmptyPanel(
                      widget.savedOnly
                          ? 'Produsele salvate vor apărea aici.'
                          : 'Nu sunt oferte disponibile momentan.',
                    )
                  : products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off, size: 48),
                          const Text('Nu am găsit produse.'),
                          TextButton(
                            onPressed: () {
                              searchController.clear();
                              setState(() {
                                query = '';
                                selectedCategory = null;
                              });
                              remember();
                            },
                            child: const Text('Șterge filtrele'),
                          ),
                          if (canLoadMore)
                            _LoadMore(
                              loading: pager.loading,
                              label: 'Caută în mai multe produse',
                              onPressed: () => loadMore(manual: true),
                            ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final viewportWidth = MediaQuery.sizeOf(context).width;
                        final columns = viewportWidth >= 1180
                            ? 3
                            : viewportWidth >= 700
                            ? 2
                            : 1;
                        Widget card(int index) {
                          final p = products[index];
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : Duration(
                                    milliseconds: 280 + (index % 6) * 50,
                                  ),
                            curve: Curves.easeOutCubic,
                            builder: (_, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 16 * (1 - value)),
                                child: child,
                              ),
                            ),
                            child: ProductTile(
                              key: ValueKey('product-${p.id}'),
                              product: p,
                              saved: saved.contains(p.id),
                              onFavorite: busy.contains(p.id)
                                  ? null
                                  : () =>
                                        toggle(p, saved.contains(p.id), reload),
                              onOpen: () async {
                                await Navigator.pushNamed(
                                  context,
                                  '/product',
                                  arguments: p.id,
                                );
                                if (mounted) await reload();
                              },
                            ),
                          );
                        }

                        final side = columns > 1 && constraints.maxWidth >= 1240
                            ? (constraints.maxWidth - 1180) / 2
                            : 16.0;
                        return RefreshIndicator(
                          onRefresh: reload,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (canLoadMore &&
                                  n.depth == 0 &&
                                  autoLoad &&
                                  !pager.loading &&
                                  n.metrics.extentAfter < 600) {
                                Future.microtask(loadMore);
                              }
                              return false;
                            },
                            child: PageStorage(
                              bucket: memory?.bucket ?? fallbackBucket,
                              child: CustomScrollView(
                                key: PageStorageKey(
                                  '$memoryKey.${columns == 1 ? 'list' : 'grid'}',
                                ),
                                slivers: [
                                  SliverPadding(
                                    padding: EdgeInsets.fromLTRB(
                                      side,
                                      4,
                                      side,
                                      canLoadMore ? 8 : 32,
                                    ),
                                    sliver: columns == 1
                                        ? SliverList.separated(
                                            itemCount: products.length,
                                            separatorBuilder: (_, _) =>
                                                const SizedBox(height: 16),
                                            itemBuilder: (_, index) =>
                                                card(index),
                                          )
                                        : SliverGrid.builder(
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: columns,
                                                  crossAxisSpacing: 18,
                                                  mainAxisSpacing: 18,
                                                  mainAxisExtent:
                                                      ((constraints.maxWidth
                                                                      .clamp(
                                                                        0,
                                                                        1180,
                                                                      ) -
                                                                  32 -
                                                                  18 *
                                                                      (columns -
                                                                          1)) /
                                                              columns) /
                                                          1.6 +
                                                      300 *
                                                          MediaQuery.textScalerOf(
                                                            context,
                                                          ).scale(1),
                                                ),
                                            itemCount: products.length,
                                            itemBuilder: (_, index) =>
                                                card(index),
                                          ),
                                  ),
                                  if (canLoadMore)
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 32,
                                        ),
                                        child: _LoadMore(
                                          loading: pager.loading,
                                          label: 'Încarcă mai multe oferte',
                                          onPressed: () =>
                                              loadMore(manual: true),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );
}

class _LoadMore extends StatelessWidget {
  const _LoadMore({
    required this.loading,
    required this.label,
    required this.onPressed,
  });
  final bool loading;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: loading
          ? const SizedBox.square(
              dimension: 32,
              child: CircularProgressIndicator(),
            )
          : OutlinedButton(
              key: const ValueKey('load-more'),
              onPressed: onPressed,
              child: Text(label),
            ),
    ),
  );
}

class _CatalogHero extends StatelessWidget {
  const _CatalogHero();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 180),
    decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage('assets/demo/rescue-bag.webp'),
        fit: BoxFit.cover,
        alignment: Alignment.centerRight,
      ),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xF2FAF9F6), Color(0xBFFAF9F6), Color(0x00FAF9F6)],
          stops: [0, .48, .82],
        ),
      ),
      child: Align(
        heightFactor: 1,
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Salvează mâncarea.\nBucură-te de preț.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Descoperă produse bune, disponibile azi, înainte să fie risipite.',
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/map'),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Explorează harta'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
