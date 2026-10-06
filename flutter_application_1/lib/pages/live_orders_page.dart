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
          return const EmptyPanel(
            'Nu ai încă nicio comandă',
            icon: Icons.receipt_long_outlined,
            detail:
                'Rezervările tale apar aici, împreună cu codul de ridicare.',
          );
        }
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              for (final order in orders)
                PageWidth(
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xffe8efdc),
                        child: Icon(Icons.shopping_bag_outlined),
                      ),
                      title: Text(
                        order['merchant_name'] as String? ??
                            'Comanda #${order['id']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusPill(order['status'] as String),
                            Text(
                              '#${order['id']} · ${orderDate(order['created_at'])} · ${(order['order_items'] as List).fold<int>(0, (n, i) => n + (i['quantity'] as int))} produse',
                            ),
                          ],
                        ),
                      ),
                      trailing: Text(
                        money(order['total_price']),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
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
      builder: (order, reload) {
        final theme = Theme.of(context);
        final status = order['status'] as String;
        Widget section(List<Widget> children) => Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            PageWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (confirmation && status != 'cancelled')
                    const _ConfirmationHeader()
                  else
                    Text(
                      'Comanda #${order['id']}',
                      style: theme.textTheme.headlineMedium,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '${confirmation ? 'Comanda #${order['id']} · ' : ''}${orderDate(order['created_at'])} · ${orderStatus(status)}',
                    textAlign: confirmation && status != 'cancelled'
                        ? TextAlign.center
                        : TextAlign.start,
                  ),
                  if (order['pickup_code'] != null && status != 'cancelled')
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: status == 'ready'
                            ? theme.colorScheme.primaryContainer
                            : const Color(0xffe8efdc),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            status == 'ready'
                                ? 'Pachetul tău este gata!'
                                : 'Codul tău de ridicare',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            '${order['pickup_code']}',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              letterSpacing: 6,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Arată codul comerciantului la ridicare.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: 20),
                  section([
                    OrderProgress(status: status),
                    const SizedBox(height: 4),
                    Align(
                      child: TextButton.icon(
                        onPressed: reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizează statusul'),
                      ),
                    ),
                    if (order['cancellation_reason'] != null)
                      Text('Motiv anulare: ${order['cancellation_reason']}'),
                  ]),
                  if (order['merchant_name'] != null) ...[
                    const SizedBox(height: 12),
                    section([
                      Text(
                        'Ridicare',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InfoRow(
                        icon: Icons.storefront_outlined,
                        text: '${order['merchant_name']}',
                        emphasis: true,
                      ),
                      if (order['pickup_address'] != null)
                        InfoRow(
                          icon: Icons.place_outlined,
                          text: '${order['pickup_address']}',
                        ),
                      if (order['pickup_window'] != null)
                        InfoRow(
                          icon: Icons.schedule_outlined,
                          text:
                              'Interval de ridicare: ${order['pickup_window']}',
                        ),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  section([
                    Text(
                      'Produse',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final item in order['order_items'])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text(item['product_name'])),
                            const SizedBox(width: 12),
                            Text(
                              '${item['quantity']} × ${money(item['unit_price'])}',
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 24),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Text('Total', style: theme.textTheme.titleLarge),
                        Text(
                          money(order['total_price']),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      order['is_demo'] == true
                          ? 'COMANDĂ DE TEST · Produse fictive. Fără plată sau ridicare reală.'
                          : 'Plata la ridicare. Nicio plată online nu a fost efectuată.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ]),
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
          ],
        );
      },
    ),
  );
}

/// Short, one-time success moment shown right after checkout.
class _ConfirmationHeader extends StatelessWidget {
  const _ConfirmationHeader();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 450),
          curve: Curves.easeOutBack,
          builder: (_, value, child) =>
              Transform.scale(scale: value, child: child),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 44,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Comanda a fost trimisă!',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
      ],
    );
  }
}

/// Colour-coded order status, readable at a glance in the history list.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      'ready' => (const Color(0xFFD9EFB4), const Color(0xFF31572C)),
      'collected' => (const Color(0xFFE6E7E2), const Color(0xFF4A4A45)),
      'cancelled' => (const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
      _ => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          orderStatus(status),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
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
