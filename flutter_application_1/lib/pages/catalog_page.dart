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
  String? selectedCategory;
  final searchController = TextEditingController();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  final busy = <int>{};
  Future<(List<Product>, Set<int>)> load() async {
    if (widget.savedOnly) {
      final saved = await widget.service.products(saved: true);
      return (saved, saved.map((p) => p.id).toSet());
    }
    final results = await Future.wait([
      widget.service.products(saved: true),
      widget.service.products(),
    ]);
    final saved = results[0];
    final products = results[1];
    return (products, saved.map((p) => p.id).toSet());
  }

  Future<void> toggle(
    Product p,
    bool saved,
    Future<void> Function() reload,
  ) async {
    if (busy.contains(p.id)) return;
    setState(() => busy.add(p.id));
    try {
      await widget.service.favorite(p.id, !saved);
      await reload();
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
        final products = data.$1
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
                MediaQuery.textScalerOf(context).scale(1) <= 1.3)
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
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                ),
              ),
            ),
            if (data.$1.any((p) => p.category?.isNotEmpty == true))
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (final category in <String?>[
                      null,
                      ...data.$1
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
                          onSelected: (_) =>
                              setState(() => selectedCategory = category),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: data.$1.isEmpty
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
                            },
                            child: const Text('Șterge filtrele'),
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
                              saved: data.$2.contains(p.id),
                              onFavorite: busy.contains(p.id)
                                  ? null
                                  : () => toggle(
                                      p,
                                      data.$2.contains(p.id),
                                      reload,
                                    ),
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

                        return RefreshIndicator(
                          onRefresh: reload,
                          child: columns == 1
                              ? ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    32,
                                  ),
                                  itemCount: products.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 16),
                                  itemBuilder: (_, index) => card(index),
                                )
                              : GridView.builder(
                                  padding: EdgeInsets.fromLTRB(
                                    constraints.maxWidth >= 1240
                                        ? (constraints.maxWidth - 1180) / 2
                                        : 16,
                                    4,
                                    constraints.maxWidth >= 1240
                                        ? (constraints.maxWidth - 1180) / 2
                                        : 16,
                                    32,
                                  ),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        crossAxisSpacing: 18,
                                        mainAxisSpacing: 18,
                                        mainAxisExtent:
                                            MediaQuery.textScalerOf(context)
                                                    .scale(1) >
                                                1.3
                                            ? 500
                                            : 390,
                                      ),
                                  itemCount: products.length,
                                  itemBuilder: (_, index) => card(index),
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

class _CatalogHero extends StatelessWidget {
  const _CatalogHero();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 180),
    decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage('assets/demo/rescue-bag.png'),
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
            ],
          ),
        ),
      ),
    ),
  );
}
