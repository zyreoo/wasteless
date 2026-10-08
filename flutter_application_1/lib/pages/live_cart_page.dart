import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../models/product.dart';
import '../services/commerce_service.dart';
import '../theme/app_theme.dart';
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
    title: 'Coș',
    index: 3,
    body: LoadPanel<Map<String, dynamic>>(
      load: widget.service.cart,
      errorTitle: 'Nu am putut încărca coșul',
      loading: const ListSkeleton(rows: 2),
      builder: (cart, reload) {
        final items = cart['items'] as List;
        if (items.isEmpty) {
          return const EmptyPanel(
            'Coșul tău este gol',
            icon: Icons.shopping_bag_outlined,
            detail: 'Alege o ofertă bună și o rezervi în câteva secunde.',
          );
        }
        final theme = Theme.of(context);
        final count = items.fold<int>(0, (n, i) => n + (i['quantity'] as int));
        final merchant = items.first['product']?['merchants']?['name'];
        final lines = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              'Coșul tău',
              subtitle: [
                count == 1 ? '1 produs' : '$count produse',
                if (merchant != null && cart['single_merchant'] != false)
                  '$merchant',
              ].join(' · '),
            ),
            const Divider(),
            for (final item in items) ...[
              _CartLine(
                item: item,
                busy: busy,
                onQuantity: (value) => change(
                  () => widget.service.quantity(item['id'], value),
                  reload,
                ),
                onRemove: () =>
                    change(() => widget.service.remove(item['id']), reload),
              ),
              const Divider(),
            ],
            const SizedBox(height: Space.s),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy
                    ? null
                    : () => change(widget.service.clear, reload),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Golește coșul'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        );
        final summary = Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sumar', style: theme.textTheme.titleMedium),
                const SizedBox(height: Space.l),
                _AmountRow(
                  count == 1 ? '1 produs' : '$count produse',
                  money(cart['subtotal'] ?? cart['total']),
                ),
                const SizedBox(height: Space.m),
                const Divider(),
                const SizedBox(height: Space.m),
                _AmountRow('Total', money(cart['total']), strong: true),
                const SizedBox(height: Space.s),
                Text(
                  'Plătești la ridicare, direct la magazin.',
                  style: theme.textTheme.bodySmall,
                ),
                if (cart['single_merchant'] == false) ...[
                  const SizedBox(height: Space.m),
                  const Pill(
                    'Un singur magazin per comandă',
                    tone: PillTone.warning,
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: Space.s),
                  Text(
                    'Elimină produsele celorlalte magazine pentru a continua.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: Space.xl),
                FilledButton(
                  onPressed: busy || cart['can_checkout'] != true
                      ? null
                      : () async {
                          await Navigator.pushNamed(context, '/checkout');
                          if (mounted) await reload();
                        },
                  child: const Text('Continuă comanda'),
                ),
              ],
            ),
          ),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                padding: EdgeInsets.all(wide ? Space.xxl : Space.l),
                children: [
                  PageWidth(
                    maxWidth: 1080,
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: lines),
                              const SizedBox(width: Space.xxl),
                              SizedBox(
                                width: 340,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 72),
                                  child: summary,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              lines,
                              const SizedBox(height: Space.l),
                              summary,
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.amount, {this.strong = false});
  final String label, amount;
  final bool strong;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.m,
      children: [
        Text(
          label,
          style: strong
              ? theme.textTheme.titleMedium
              : theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
        ),
        Text(
          amount,
          style: strong
              ? theme.textTheme.headlineSmall
              : theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
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
    final stepper = QuantityStepper(
      value: quantity,
      decrementTooltip: quantity == 1 ? 'Elimină produsul' : 'Scade cantitatea',
      decrementIcon: quantity == 1 ? Icons.delete_outline : Icons.remove,
      onDecrement: busy ? null : () => onQuantity(quantity - 1),
      onIncrement: busy || quantity >= 99
          ? null
          : () => onQuantity(quantity + 1),
    );
    final total = Text(
      item['line_total'] == null ? '—' : money(item['line_total']),
      textAlign: TextAlign.end,
      style: theme.textTheme.titleMedium,
    );
    final remove = IconButton(
      tooltip: 'Elimină',
      onPressed: busy ? null : onRemove,
      icon: const Icon(Icons.close, size: 20),
    );
    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.s),
            child: SizedBox(width: 72, child: ProductImage(product)),
          ),
        const SizedBox(width: Space.l),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product?.name ?? 'Produs indisponibil',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              if (product != null)
                Text(
                  '${money(product.price)} / bucată',
                  style: theme.textTheme.bodySmall,
                ),
              if (item['available'] != true)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Text(
                    'Nu mai este disponibil în cantitatea aleasă.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.l),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 560
            ? Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: Space.l),
                  stepper,
                  SizedBox(width: 96, child: total),
                  const SizedBox(width: Space.xs),
                  remove,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: info),
                      remove,
                    ],
                  ),
                  const SizedBox(height: Space.m),
                  Row(
                    children: [
                      stepper,
                      const SizedBox(width: Space.m),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: total,
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
