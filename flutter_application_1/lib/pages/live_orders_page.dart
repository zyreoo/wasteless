import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/product.dart';
import '../services/commerce_service.dart';
import '../widgets/live_page.dart';

String orderStatus(String value) => switch (value) {
  'confirmed' => 'Confirmată',
  'collected' => 'Ridicată',
  'cancelled' => 'Anulată',
  _ => value,
};
String orderDate(String value) =>
    DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(value).toLocal());

class LiveOrdersPage extends StatelessWidget {
  const LiveOrdersPage({super.key, required this.service});
  final CommerceService service;
  @override
  Widget build(BuildContext context) => LiveScaffold(
    title: 'Comenzile mele',
    index: 4,
    body: LoadPanel<List<Map<String, dynamic>>>(
      load: service.orders,
      builder: (orders, reload) {
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
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/order-detail',
                      arguments: order['id'],
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
          const Text(
            'Plata la ridicare. Nicio plată online nu a fost efectuată.',
          ),
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
