import '../merchant/order_actions.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../auth/auth_controller.dart';
import '../models/product.dart';
import '../services/commerce_service.dart';
import '../widgets/live_page.dart';

String orderStatus(String value) => switch (value) {
  'confirmed' => 'Trimisă comerciantului',
  'accepted' => 'Acceptată',
  'ready' => 'Gata de ridicare',
  'collected' => 'Ridicată',
  'cancelled' => 'Anulată',
  _ => value,
};
String orderDate(String value) =>
    DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(value).toLocal());

class LiveOrdersPage extends StatefulWidget {
  const LiveOrdersPage({super.key, required this.service});
  final CommerceService service;
  @override
  State<LiveOrdersPage> createState() => _LiveOrdersPageState();
}

class _LiveOrdersPageState extends State<LiveOrdersPage> {
  /// History starts with the newest page; older orders load on request.
  late final pager = widget.service.orderPager();

  Future<void> loadOlder() async {
    if (pager.loading) return;
    setState(() {});
    try {
      await pager.more();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AuthController.message(e))));
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => LiveScaffold(
    title: 'Comenzile mele',
    index: 4,
    body: LoadPanel<List<Map<String, dynamic>>>(
      load: pager.refresh,
      builder: (_, reload) {
        final orders = pager.items;
        if (orders.isEmpty) {
          return const EmptyPanel('Comenzile tale vor apărea aici.');
        }
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final order in orders)
                Card(
                  child: ListTile(
                    isThreeLine: true,
                    title: Text('Comanda #${order['id']}'),
                    subtitle: Text(
                      '${orderDate(order['created_at'])}\n${orderStatus(order['status'])} · ${(order['order_items'] as List).fold<int>(0, (n, i) => n + (i['quantity'] as int))} produse',
                    ),
                    trailing: Text(money(order['total_price'])),
                    onTap: () async {
                      await Navigator.pushNamed(
                        context,
                        '/order-detail',
                        arguments: order['id'],
                      );
                      await reload();
                    },
                  ),
                ),
              if (pager.hasMore)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: pager.loading
                        ? const SizedBox.square(
                            dimension: 32,
                            child: CircularProgressIndicator(),
                          )
                        : OutlinedButton(
                            key: const ValueKey('load-older-orders'),
                            onPressed: loadOlder,
                            child: const Text('Vezi comenzi mai vechi'),
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class LiveOrderDetailPage extends StatelessWidget {
  const LiveOrderDetailPage({
    super.key,
    required this.service,
    required this.id,
    this.confirmation = false,
  });
  final CommerceService service;
  final int id;
  final bool confirmation;
  @override
  Widget build(BuildContext context) => LiveScaffold(
    title: confirmation ? 'Comandă confirmată' : 'Comanda #$id',
    body: LoadPanel<Map<String, dynamic>>(
      load: () => service.order(id),
      builder: (order, reload) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Comanda #${order['id']}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            '${orderDate(order['created_at'])} · ${orderStatus(order['status'])}',
          ),
          const SizedBox(height: 20),
          OrderProgress(status: order['status'] as String),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizează statusul'),
          ),
          if (order['merchant_name'] != null)
            Text(
              '${order['merchant_name']}\n${order['pickup_address']}\nRidicare: ${order['pickup_window']}',
            ),
          if (order['pickup_code'] != null && order['status'] != 'cancelled')
            Container(
              margin: const EdgeInsets.symmetric(vertical: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: order['status'] == 'ready'
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order['status'] == 'ready'
                        ? 'Pachetul tău este gata!'
                        : 'Codul tău de ridicare',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    '${order['pickup_code']}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      letterSpacing: 3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Arată codul comerciantului la ridicare.'),
                ],
              ),
            ),
          if (order['cancellation_reason'] != null)
            Text('Motiv anulare: ${order['cancellation_reason']}'),
          const SizedBox(height: 16),
          for (final item in order['order_items'])
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item['product_name']),
              subtitle: Text(
                '${item['quantity']} × ${money(item['unit_price'])}',
              ),
            ),
          const Divider(),
          Text(
            'Total: ${money(order['total_price'])}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(
            order['is_demo'] == true
                ? 'COMANDĂ DE TEST · Produse fictive. Fără plată sau ridicare reală.'
                : 'Plata la ridicare. Nicio plată online nu a fost efectuată.',
          ),
          const SizedBox(height: 16),
          OrderActions(order: order, service: service, reload: reload),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (_) => false,
            ),
            child: const Text('Înapoi la produse'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/history'),
            child: const Text('Vezi comenzile mele'),
          ),
        ],
      ),
    ),
  );
}

class OrderProgress extends StatelessWidget {
  const OrderProgress({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.cancel_outlined),
        title: Text('Comandă anulată'),
        subtitle: Text('Produsele au revenit în stoc.'),
      );
    }
    final current = [
      'confirmed',
      'accepted',
      'ready',
      'collected',
    ].indexOf(status);
    const labels = ['Trimisă', 'Acceptată', 'Pregătită', 'Ridicată'];
    return Semantics(
      label: 'Status comandă: ${orderStatus(status)}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          4,
          (i) => Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: i == 0
                            ? Colors.transparent
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: i <= current
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                      child: Icon(
                        i < current
                            ? Icons.check
                            : i == current
                            ? Icons.radio_button_checked
                            : Icons.circle_outlined,
                        size: 17,
                        color: i <= current
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: i == 3
                            ? Colors.transparent
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: i == current
                        ? FontWeight.w800
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
