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
        if ((cart['items'] as List).isEmpty) {
          return const EmptyPanel('Coșul tău este gol');
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final item in cart['items'])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item['product']?['name'] as String? ?? 'Produs indisponibil',
                ),
                subtitle: Text('Cantitate: ${item['quantity']}'),
                trailing: Text(
                  item['line_total'] == null ? '—' : money(item['line_total']),
                ),
              ),
            const Divider(),
            Text(
              'Total: ${money(cart['total'])}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              (cart['items'] as List).every(
                    (i) => i['product']?['is_demo'] == true,
                  )
                  ? 'COMANDĂ DE TEST · Produse fictive, fără plată sau ridicare reală.'
                  : 'Plata se face la ridicare. Confirmarea comenzii nu retrage bani.',
            ),
            if (cart['single_merchant'] == false)
              const Text(
                'O comandă trebuie să conțină produse de la un singur comerciant. Revino în coș pentru a elimina produsele celorlalți comercianți.',
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy || cart['can_checkout'] != true ? null : confirm,
              child: Text(busy ? 'Se trimite comanda…' : 'Confirmă comanda'),
            ),
          ],
        );
      },
    ),
  );
}
