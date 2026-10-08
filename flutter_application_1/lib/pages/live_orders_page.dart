import '../merchant/order_actions.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../auth/auth_controller.dart';
import '../models/product.dart';
import '../services/commerce_service.dart';
import '../theme/app_theme.dart';
import '../widgets/live_page.dart';

String orderStatus(String value) => switch (value) {
  'confirmed' => 'În așteptare',
  'accepted' => 'Acceptată',
  'ready' => 'Pregătită',
  'collected' => 'Ridicată',
  'cancelled' => 'Anulată',
  'not_collected' => 'Neridicată',
  _ => value,
};

/// Orders the shop still has to hand over.
const openStatuses = {'confirmed', 'accepted', 'ready'};

/// Orders refresh on their own so new orders and status changes show up
/// without pulling to refresh.
const ordersRefresh = Duration(seconds: 30);

/// True once an open order's pickup time is over: the end of its dated window,
/// or, for the shop's usual daily window, any day after the order was placed.
bool pickupEnded(Map<String, dynamic> order, {DateTime? now}) {
  if (!openStatuses.contains(order['status'])) return false;
  final at = now ?? DateTime.now();
  final end = parseTime(order['pickup_end']);
  if (end != null) return !end.isAfter(at);
  final placed = DateTime.parse(order['created_at'] as String).toLocal();
  return DateUtils.dateOnly(placed).isBefore(DateUtils.dateOnly(at));
}

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
    title: 'Comenzi',
    index: 4,
    body: LoadPanel<List<Map<String, dynamic>>>(
      load: pager.refresh,
      refreshEvery: ordersRefresh,
      errorTitle: 'Nu am putut încărca comenzile',
      loading: const ListSkeleton(),
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
        final theme = Theme.of(context);
        return LayoutBuilder(
          builder: (context, constraints) => RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: EdgeInsets.all(
                constraints.maxWidth >= 600 ? Space.xxl : Space.l,
              ),
              children: [
                PageWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PageHeader(
                        'Comenzile mele',
                        subtitle: 'Statusul și codul de ridicare pentru fiecare comandă.',
                      ),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final (i, order) in orders.indexed) ...[
                              if (i > 0) const Divider(),
                              InkWell(
                                onTap: () async {
                                  await Navigator.pushNamed(
                                    context,
                                    '/order-detail',
                                    arguments: order['id'],
                                  );
                                  await reload();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Space.l,
                                    vertical: Space.l,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceMuted,
                                          borderRadius: BorderRadius.circular(
                                            Radii.m,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.storefront_outlined,
                                          size: 20,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: Space.l),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              order['merchant_name']
                                                      as String? ??
                                                  'Comanda #${order['id']}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleSmall,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '#${order['id']} · ${orderDate(order['created_at'])} · ${itemCount(order)}',
                                              maxLines: 2,
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: Space.m),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            money(order['total_price']),
                                            style: theme.textTheme.titleSmall,
                                          ),
                                          const SizedBox(height: Space.xs),
                                          StatusPill(order['status'] as String),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (pager.hasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: Space.l),
                          child: Center(
                            child: pager.loading
                                ? const SizedBox.square(
                                    dimension: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
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
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

String itemCount(Map<String, dynamic> order) {
  final n = (order['order_items'] as List).fold<int>(
    0,
    (n, i) => n + (i['quantity'] as int),
  );
  return n == 1 ? '1 produs' : '$n produse';
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
      refreshEvery: ordersRefresh,
      errorTitle: 'Nu am putut încărca comanda',
      loading: const ListSkeleton(rows: 3, thumbnail: false),
      builder: (order, reload) {
        final theme = Theme.of(context);
        final status = order['status'] as String;
        final celebrate = confirmation && status != 'cancelled';
        final code =
            order['pickup_code'] != null &&
                status != 'cancelled' &&
                status != 'not_collected'
            ? '${order['pickup_code']}'
            : null;
        return LayoutBuilder(
          builder: (context, constraints) => ListView(
            padding: EdgeInsets.all(
              constraints.maxWidth >= 600 ? Space.xxl : Space.l,
            ),
            children: [
              PageWidth(
                maxWidth: 640,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (celebrate)
                      _ConfirmationHeader(
                        merchant: order['merchant_name'] as String?,
                        reference:
                            'Comanda #${order['id']} · ${orderDate(order['created_at'])}',
                      )
                    else
                      Wrap(
                        spacing: Space.m,
                        runSpacing: Space.s,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Comanda #${order['id']}',
                            style: theme.textTheme.headlineMedium,
                          ),
                          StatusPill(status),
                        ],
                      ),
                    if (!celebrate) ...[
                      const SizedBox(height: Space.xs),
                      Text(
                        '${orderDate(order['created_at'])} · ${order['merchant_name'] ?? ''}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (code != null) ...[
                      const SizedBox(height: Space.xl),
                      _PickupCode(code: code, ready: status == 'ready'),
                    ],
                    if (pickupEnded(order)) ...[
                      const SizedBox(height: Space.l),
                      const InfoRow(
                        icon: Icons.schedule_outlined,
                        text: 'Intervalul de ridicare s-a încheiat. Dacă nu ai ajuns la timp, contactează magazinul.',
                      ),
                    ],
                    const SizedBox(height: Space.xl),
                    OrderProgress(status: status),
                    Align(
                      child: TextButton.icon(
                        onPressed: reload,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Actualizează statusul'),
                      ),
                    ),
                    if (order['cancellation_reason'] != null)
                      Text(
                        'Motiv anulare: ${order['cancellation_reason']}',
                        style: theme.textTheme.bodySmall,
                      ),
                    if (order['merchant_name'] != null) ...[
                      const SizedBox(height: Space.l),
                      const Divider(),
                      const SizedBox(height: Space.xl),
                      const SectionTitle('Ridicare'),
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
                      if ((pickupWindowLabel(
                                parseTime(order['pickup_start']),
                                parseTime(order['pickup_end']),
                              ) ??
                              order['pickup_window']) !=
                          null)
                        InfoRow(
                          icon: Icons.schedule_outlined,
                          text:
                              'Interval de ridicare: ${pickupWindowLabel(parseTime(order['pickup_start']), parseTime(order['pickup_end'])) ?? order['pickup_window']}',
                        ),
                    ],
                    const SizedBox(height: Space.xl),
                    const Divider(),
                    const SizedBox(height: Space.xl),
                    const SectionTitle('Produse'),
                    for (final item in order['order_items'])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: Space.s),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 36,
                              child: Text(
                                '${item['quantity']}×',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Expanded(child: Text(item['product_name'])),
                            const SizedBox(width: Space.m),
                            Text(
                              money(
                                num.parse('${item['unit_price']}') *
                                    (item['quantity'] as int),
                              ),
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: Space.m),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Space.m,
                      children: [
                        Text('Total', style: theme.textTheme.titleMedium),
                        Text(
                          money(order['total_price']),
                          style: theme.textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.s),
                    Text(
                      'Plata la ridicare. Nicio plată online nu a fost efectuată.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: Space.xl),
                    OrderActions(
                      order: order,
                      service: service,
                      reload: reload,
                    ),
                    const SizedBox(height: Space.xl),
                    FilledButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (_) => false,
                      ),
                      child: const Text('Înapoi la oferte'),
                    ),
                    const SizedBox(height: Space.s),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/history'),
                      child: const Text('Vezi comenzile mele'),
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

/// Short success moment shown right after checkout.
class _ConfirmationHeader extends StatelessWidget {
  const _ConfirmationHeader({required this.merchant, required this.reference});
  final String? merchant;
  final String reference;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: Space.s),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 360),
          curve: Curves.easeOutBack,
          builder: (_, value, child) =>
              Transform.scale(scale: .6 + .4 * value, child: child),
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 32,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(height: Space.l),
        Text(
          'Comanda e confirmată',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: Space.xs),
        Text(
          merchant == null
              ? 'Am rezervat produsele pentru tine.'
              : 'Am rezervat produsele la $merchant.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          reference,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PickupCode extends StatelessWidget {
  const _PickupCode({required this.code, required this.ready});
  final String code;
  final bool ready;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xl,
        vertical: Space.xl,
      ),
      decoration: BoxDecoration(
        color: ready ? AppColors.brandSoft : AppColors.surface,
        border: Border.all(color: ready ? AppColors.brand : AppColors.border),
        borderRadius: BorderRadius.circular(Radii.l),
      ),
      child: Column(
        children: [
          Text(
            ready ? 'Pachetul tău este gata' : 'Cod de ridicare',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: Space.s),
          SelectableText(
            code,
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              letterSpacing: 6,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: Space.s),
          Text(
            'Arată codul la magazin când ridici comanda.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Colour-coded order status, readable at a glance.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => Pill(
    orderStatus(status),
    tone: switch (status) {
      'ready' => PillTone.success,
      'accepted' => PillTone.brand,
      'collected' => PillTone.neutral,
      'cancelled' || 'not_collected' => PillTone.error,
      _ => PillTone.warning,
    },
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
    if (status == 'not_collected') {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.event_busy_outlined),
        title: Text('Comanda nu a fost ridicată'),
        subtitle: Text('Intervalul de ridicare s-a încheiat.'),
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
