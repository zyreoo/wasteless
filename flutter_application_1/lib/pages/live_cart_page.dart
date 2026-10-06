import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../models/product.dart';
import '../services/commerce_service.dart';
import '../widgets/live_page.dart';
import '../widgets/product_tile.dart';

class LiveCartPage extends StatefulWidget {
  const LiveCartPage({super.key, required this.service});
  final CommerceService service;
  @override
  State<LiveCartPage> createState() => _LiveCartPageState();
}

class _LiveCartPageState extends State<LiveCartPage> {
  bool busy = false;
  Future<void> change(
    Future<void> Function() operation,
    Future<void> Function() reload,
  ) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
      await reload();
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
    title: 'Coșul tău',
    index: 3,
    body: LoadPanel<Map<String, dynamic>>(
      load: widget.service.cart,
      builder: (cart, reload) {
        final items = cart['items'] as List;
        if (items.isEmpty) {
          return const EmptyPanel(
            'Coșul tău este gol',
            icon: Icons.shopping_bag_outlined,
            detail:
                'Alege o ofertă din catalog și o rezervi în câteva secunde.',
          );
        }
        final theme = Theme.of(context);
        final allDemo = items.every((i) => i['product']?['is_demo'] == true);
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              PageWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in items) ...[
                      _CartLine(
                        item: item,
                        busy: busy,
                        onQuantity: (value) => change(
                          () => widget.service.quantity(item['id'], value),
                          reload,
                        ),
                        onRemove: () => change(
                          () => widget.service.remove(item['id']),
                          reload,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 4),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              children: [
                                Text(
                                  'Total',
                                  style: theme.textTheme.titleLarge,
                                ),
                                Text(
                                  money(cart['total']),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: theme.colorScheme.primary,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              allDemo
                                  ? 'Produse demonstrative: comanda nu implică plată.'
                                  : 'Plătești la ridicare, direct la comerciant.',
                            ),
                            if (cart['single_merchant'] == false) ...[
                              const SizedBox(height: 12),
                              InfoRow(
                                icon: Icons.storefront_outlined,
                                text: 'Alege produse de la un singur comerciant per comandă. Elimină produsele celorlalți comercianți pentru a continua.',
                              ),
                            ],
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: busy || cart['can_checkout'] != true
                                  ? null
                                  : () async {
                                      await Navigator.pushNamed(
                                        context,
                                        '/checkout',
                                      );
                                      if (mounted) await reload();
                                    },
                              child: const Text('Continuă comanda'),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => change(widget.service.clear, reload),
                              child: const Text('Golește coșul'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.item,
    required this.busy,
    required this.onQuantity,
    required this.onRemove,
  });
  final Map<String, dynamic> item;
  final bool busy;
  final void Function(int quantity) onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = item['product'] as Map<String, dynamic>?;
    final product = raw == null ? null : Product.fromJson(raw);
    final quantity = item['quantity'] as int;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(width: 88, child: ProductImage(product)),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product?.name ?? 'Produs indisponibil',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (product?.merchant?['name'] != null)
                        Text(
                          product!.merchant!['name'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      if (product != null)
                        Text(
                          '${money(product.price)} / bucată',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Elimină',
                  visualDensity: VisualDensity.compact,
                  onPressed: busy ? null : onRemove,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (item['available'] != true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Produsul nu mai este disponibil în cantitatea aleasă.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: quantity == 1
                      ? 'Elimină produsul'
                      : 'Scade cantitatea',
                  onPressed: busy ? null : () => onQuantity(quantity - 1),
                  icon: Icon(
                    quantity == 1 ? Icons.delete_outline : Icons.remove,
                  ),
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
                  onPressed: busy || quantity >= 99
                      ? null
                      : () => onQuantity(quantity + 1),
                  icon: const Icon(Icons.add),
                ),
                if (item['line_total'] != null)
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        money(item['line_total']),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
