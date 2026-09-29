import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../services/commerce_service.dart';
import '../models/product.dart';
import '../widgets/live_page.dart';
import '../widgets/product_tile.dart';

class LiveProductPage extends StatefulWidget {
  const LiveProductPage({super.key, required this.id, required this.service});
  final int id;
  final CommerceService service;
  @override
  State<LiveProductPage> createState() => _LiveProductPageState();
}

class _LiveProductPageState extends State<LiveProductPage> {
  int quantity = 1;
  bool busy = false;
  bool? saved;
  Future<Product> load() async {
    final results = await Future.wait([
      widget.service.products(saved: true),
      widget.service.product(widget.id),
    ]);
    final favorites = results[0] as List<Product>;
    saved = favorites.any((p) => p.id == widget.id);
    return results[1] as Product;
  }

  Future<void> toggleFavorite() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final existing =
          saved ??
          (await widget.service.products(saved: true))
              .any((p) => p.id == widget.id);
      await widget.service.favorite(widget.id, !existing);
      if (mounted) setState(() => saved = !existing);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AuthController.message(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> add() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.service.add(widget.id, quantity);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Produs adăugat în coș')));
        await Navigator.pushNamed(context, '/cart');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AuthController.message(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LiveScaffold(
    title: 'Detalii produs',
    body: LoadPanel<Product>(
      load: load,
      builder: (p, reload) => LayoutBuilder(
        builder: (context, constraints) {
          final picture = Hero(
            tag: 'product-image-${p.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: ProductImage(p),
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(p.name, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                money(p.price),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (p.description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(p.description!),
                ),
              TextButton.icon(
                onPressed: busy ? null : toggleFavorite,
                icon: Icon(
                  saved == true ? Icons.favorite : Icons.favorite_border,
                ),
                label: Text(
                  saved == true ? 'Elimină din favorite' : 'Salvează produsul',
                ),
              ),
              Text(p.stock > 0 ? '${p.stock} disponibile' : 'Stoc epuizat'),
              const SizedBox(height: 20),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Scade cantitatea',
                    onPressed: busy || quantity <= 1
                        ? null
                        : () => setState(() => quantity--),
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$quantity'),
                  IconButton(
                    tooltip: 'Crește cantitatea',
                    onPressed: busy || quantity >= p.stock || quantity >= 99
                        ? null
                        : () => setState(() => quantity++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: busy || p.stock < quantity ? null : add,
                icon: const Icon(Icons.shopping_bag_outlined),
                label: Text(busy ? 'Se adaugă…' : 'Adaugă în coș'),
              ),
            ],
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: constraints.maxWidth >= 800
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: picture),
                          const SizedBox(width: 40),
                          Expanded(child: details),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          picture,
                          const SizedBox(height: 24),
                          details,
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
