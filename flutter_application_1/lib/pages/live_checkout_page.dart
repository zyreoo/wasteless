import 'dart:math';

import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../models/product.dart';
import '../services/commerce_service.dart';
import '../theme/app_theme.dart';
import '../widgets/live_page.dart';

String checkoutKey() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class LiveCheckoutPage extends StatefulWidget {
  const LiveCheckoutPage({super.key, required this.service});
  final CommerceService service;
  @override
  State<LiveCheckoutPage> createState() => _LiveCheckoutPageState();
}

class _LiveCheckoutPageState extends State<LiveCheckoutPage> {
  final key = checkoutKey();
  bool busy = false;
  Future<void> confirm() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final order = await widget.service.checkout(key);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/order-confirm',
          (r) => r.isFirst,
          arguments: order['id'],
        );
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
    title: 'Finalizare comandă',
    body: LoadPanel<Map<String, dynamic>>(
      load: widget.service.cart,
      errorTitle: 'Nu am putut încărca comanda',
      loading: const ListSkeleton(rows: 3, thumbnail: false),
      builder: (cart, reload) {
        final items = cart['items'] as List;
        if (items.isEmpty) {
          return const EmptyPanel(
            'Coșul tău este gol',
            icon: Icons.shopping_bag_outlined,
            detail: 'Adaugă o ofertă în coș înainte să finalizezi comanda.',
          );
        }
        final theme = Theme.of(context);
        final merchant = (items.first['product']?['merchants'] as Map?)
            ?.cast<String, dynamic>();
        final first = items.first['product'] as Map<String, dynamic>?;
        final pickup = first == null
            ? null
            : Product.fromJson(first).pickupLabel;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              'Finalizează comanda',
              subtitle: 'Verifică detaliile înainte să confirmi.',
            ),
            if (merchant != null) ...[
              const SectionTitle('Ridicare'),
              InfoRow(
                icon: Icons.storefront_outlined,
                text: '${merchant['name']}',
                emphasis: true,
              ),
              if (merchant['address'] != null)
                InfoRow(
                  icon: Icons.place_outlined,
                  text: '${merchant['address']}',
                ),
              if (pickup != null)
                InfoRow(
                  icon: Icons.schedule_outlined,
                  text: 'Interval de ridicare: $pickup',
                ),
              const SizedBox(height: Space.xl),
              const Divider(),
              const SizedBox(height: Space.xl),
            ],
            const SectionTitle('Comanda ta'),
            for (final item in items)
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
                    Expanded(
                      child: Text(
                        '${item['product']?['name'] ?? 'Produs indisponibil'}',
                      ),
                    ),
                    const SizedBox(width: Space.m),
                    Text(
                      item['line_total'] == null
                          ? '—'
                          : money(item['line_total']),
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
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
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Space.m,
                  children: [
                    Text('Total', style: theme.textTheme.titleMedium),
                    Text(
                      money(cart['total']),
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: Space.l),
                const Divider(),
                const SizedBox(height: Space.m),
                const InfoRow(
                  icon: Icons.payments_outlined,
                  text: 'Plătești la ridicare. Confirmarea nu retrage bani.',
                ),
                const InfoRow(
                  icon: Icons.qr_code_2_outlined,
                  text: 'Primești un cod de ridicare pe care îl arăți la magazin.',
                ),
                if (cart['single_merchant'] == false)
                  const InfoRow(
                    icon: Icons.info_outline,
                    text: 'O comandă poate conține produse de la un singur magazin. Revino în coș pentru a elimina celelalte produse.',
                  ),
                const SizedBox(height: Space.xl),
                FilledButton(
                  onPressed: busy || cart['can_checkout'] != true
                      ? null
                      : confirm,
                  child: busy
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: Space.m),
                            Flexible(
                              child: Text(
                                'Se trimite comanda…',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : const Text('Confirmă comanda'),
                ),
              ],
            ),
          ),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return ListView(
              padding: EdgeInsets.all(wide ? Space.xxl : Space.l),
              children: [
                PageWidth(
                  maxWidth: 1000,
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: details),
                            const SizedBox(width: Space.x3),
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
                            details,
                            const SizedBox(height: Space.xl),
                            summary,
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}
