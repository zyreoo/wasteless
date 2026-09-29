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
            .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
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
                    decoration: InputDecoration(
                      hintText: 'Caută un produs',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Șterge căutarea',
                              onPressed: () => setState(() => query = ''),
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                ),
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
                  ? const Center(child: Text('Nu am găsit produse.'))
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
                            duration: Duration(milliseconds: 280 + index * 70),
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
