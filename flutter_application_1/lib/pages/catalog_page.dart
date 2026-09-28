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
    final saved = await widget.service.products(saved: true);
    final products = widget.savedOnly ? saved : await widget.service.products();
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Caută un produs',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => query = v),
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
                  : RefreshIndicator(
                      onRefresh: reload,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          for (final p in products)
                            ProductTile(
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
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );
}
