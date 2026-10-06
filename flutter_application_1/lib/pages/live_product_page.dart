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
          final theme = Theme.of(context);
          final original = p.originalPrice;
          final discount = original != null && original > p.price
              ? ((1 - p.price / original) * 100).round()
              : null;
          final merchant = p.merchant;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (merchant?['name'] != null)
                Text(
                  merchant!['name'] as String,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 6),
              Text(p.name, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    money(p.price),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (discount != null) ...[
                    Text(
                      money(original),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9EFB4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          'Economisești $discount%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF31572C),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (p.isDemo) ...[
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: InfoRow(
                      icon: Icons.info_outline,
                      text: 'Produs fictiv. Comanda testează fluxul; nu presupune livrare sau plată reală.',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (merchant?['pickup_window'] != null)
                InfoRow(
                  icon: Icons.schedule_outlined,
                  text: 'Ridicare: ${merchant!['pickup_window']}',
                ),
              if (merchant?['address'] != null)
                InfoRow(
                  icon: Icons.place_outlined,
                  text: merchant!['address'] as String,
                ),
              if (p.allergens != null)
                InfoRow(
                  icon: Icons.health_and_safety_outlined,
                  text: 'Alergeni: ${p.allergens}',
                ),
              InfoRow(
                icon: p.stock > 0
                    ? Icons.inventory_2_outlined
                    : Icons.remove_shopping_cart_outlined,
                text: p.stock == 0
                    ? 'Stoc epuizat'
                    : p.stock <= 3
                    ? 'Ultimele ${p.stock} disponibile'
                    : '${p.stock} disponibile',
              ),
              if (p.description?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text(
                  p.description!,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Scade cantitatea',
                          onPressed: busy || quantity <= 1
                              ? null
                              : () => setState(() => quantity--),
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$quantity',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Crește cantitatea',
                          onPressed:
                              busy || quantity >= p.stock || quantity >= 99
                              ? null
                              : () => setState(() => quantity++),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton.outlined(
                    tooltip: saved == true
                        ? 'Elimină din favorite'
                        : 'Salvează produsul',
                    onPressed: busy ? null : toggleFavorite,
                    icon: Icon(
                      saved == true ? Icons.favorite : Icons.favorite_border,
                      color: saved == true ? const Color(0xFFC0392B) : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy || p.stock < quantity ? null : add,
                icon: const Icon(Icons.shopping_bag_outlined),
                label: Text(
                  busy
                      ? 'Se adaugă…'
                      : p.stock == 0
                      ? 'Stoc epuizat'
                      : 'Adaugă în coș',
                ),
              ),
              if (p.stock > 0 && !p.isDemo) ...[
                const SizedBox(height: 8),
                Text(
                  'Plătești la ridicare, direct la comerciant.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
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
