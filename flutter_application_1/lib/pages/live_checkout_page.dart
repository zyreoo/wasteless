import 'dart:math';

import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../models/product.dart';
import '../services/commerce_service.dart';
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
    title: 'Confirmă comanda',
    body: LoadPanel<Map<String, dynamic>>(
      load: widget.service.cart,
      builder: (cart, reload) {
        final items = cart['items'] as List;
        if (items.isEmpty) {
          return const EmptyPanel(
            'Coșul tău este gol',
            icon: Icons.shopping_bag_outlined,
          );
        }
        final theme = Theme.of(context);
        final merchant = (items.first['product']?['merchants'] as Map?)
            ?.cast<String, dynamic>();
        final allDemo = items.every((i) => i['product']?['is_demo'] == true);
        Widget section(String title, List<Widget> children) => Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...children,
              ],
            ),
          ),
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            PageWidth(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (merchant != null) ...[
                    section('Ridicare', [
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
                      if (merchant['pickup_window'] != null)
                        InfoRow(
                          icon: Icons.schedule_outlined,
                          text:
                              'Interval de ridicare: ${merchant['pickup_window']}',
                        ),
                    ]),
                    const SizedBox(height: 12),
                  ],
                  section('Produsele tale', [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${item['quantity']} × ${item['product']?['name'] ?? 'Produs indisponibil'}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              item['line_total'] == null
                                  ? '—'
                                  : money(item['line_total']),
                              style: theme.textTheme.titleSmall,
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
                          money(cart['total']),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 16),
                  InfoRow(
                    icon: allDemo
                        ? Icons.science_outlined
                        : Icons.payments_outlined,
                    text: allDemo
                        ? 'COMANDĂ DE TEST · Produse fictive, fără plată sau ridicare reală.'
                        : 'Plata se face la ridicare. Confirmarea comenzii nu retrage bani.',
                  ),
                  const InfoRow(
                    icon: Icons.qr_code_2_outlined,
                    text: 'După confirmare primești un cod de ridicare pe care îl arăți comerciantului.',
                  ),
                  if (cart['single_merchant'] == false)
                    const InfoRow(
                      icon: Icons.storefront_outlined,
                      text: 'O comandă trebuie să conțină produse de la un singur comerciant. Revino în coș pentru a elimina produsele celorlalți comercianți.',
                    ),
                  const SizedBox(height: 20),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
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
          ],
        );
      },
    ),
  );
}
