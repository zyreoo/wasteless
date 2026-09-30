import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../models/product.dart';
import '../services/commerce_service.dart';
import '../widgets/live_page.dart';

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
        if (items.isEmpty) return const EmptyPanel('Coșul tău este gol');
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final item in items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['product']?['name'] as String? ??
                              'Produs indisponibil',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (item['line_total'] != null)
                          Text(money(item['line_total'])),
                        if (item['available'] != true)
                          const Text(
                            'Produsul nu mai este disponibil în cantitatea aleasă.',
                          ),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            IconButton(
                              tooltip: item['quantity'] == 1
                                  ? 'Elimină produsul'
                                  : 'Scade cantitatea',
                              onPressed: busy
                                  ? null
                                  : () => change(
                                      () => widget.service.quantity(
                                        item['id'],
                                        item['quantity'] - 1,
                                      ),
                                      reload,
                                    ),
                              icon: const Icon(Icons.remove),
                            ),
                            Text('${item['quantity']}'),
                            IconButton(
                              tooltip: 'Crește cantitatea',
                              onPressed: busy || item['quantity'] >= 99
                                  ? null
                                  : () => change(
                                      () => widget.service.quantity(
                                        item['id'],
                                        item['quantity'] + 1,
                                      ),
                                      reload,
                                    ),
                              icon: const Icon(Icons.add),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => change(
                                      () => widget.service.remove(item['id']),
                                      reload,
                                    ),
                              child: const Text('Elimină'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Total: ${money(cart['total'])}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (cart['single_merchant'] == false)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Alege produse de la un singur comerciant per comandă. Elimină produsele celorlalți comercianți pentru a continua.',
                  ),
                ),
              FilledButton(
                onPressed: busy || cart['can_checkout'] != true
                    ? null
                    : () async {
                        await Navigator.pushNamed(context, '/checkout');
                        if (mounted) await reload();
                      },
                child: const Text('Continuă comanda'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => change(widget.service.clear, reload),
                child: const Text('Golește coșul'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
