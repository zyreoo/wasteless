import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../services/commerce_service.dart';

class OrderActions extends StatefulWidget {
  const OrderActions({
    super.key,
    required this.order,
    required this.service,
    required this.reload,
    this.merchant = false,
  });
  final Map<String, dynamic> order;
  final CommerceService service;
  final Future<void> Function() reload;
  final bool merchant;
  @override
  State<OrderActions> createState() => _OrderActionsState();
}

class _OrderActionsState extends State<OrderActions> {
  bool busy = false;
  Future<void> act(String status) async {
    String input = '';
    if (status == 'collected' || status == 'cancelled') {
      String draft = '';
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            status == 'collected' ? 'Confirmă ridicarea' : 'Anulează comanda',
          ),
          content: TextField(
            onChanged: (value) => draft = value,
            autofocus: true,
            maxLength: status == 'collected' ? 8 : 500,
            decoration: InputDecoration(
              labelText: status == 'collected'
                  ? 'Codul oferit de client'
                  : 'Motivul anulării',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Înapoi'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, draft.trim()),
              child: const Text('Confirmă'),
            ),
          ],
        ),
      );
      if (result == null || !mounted) return;
      input = result;
      if (input.length < (status == 'collected' ? 8 : 3)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Completează codul sau motivul înainte de confirmare.',
            ),
          ),
        );
        return;
      }
    }
    if (!mounted || busy) return;
    setState(() => busy = true);
    try {
      await widget.service.transition(
        widget.order['id'] as int,
        status,
        code: status == 'collected' ? input : '',
        reason: status == 'cancelled' ? input : '',
      );
      await widget.reload();
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
  Widget build(BuildContext context) {
    final status = widget.order['status'];
    final next = {
      'confirmed': 'accepted',
      'accepted': 'ready',
      'ready': 'collected',
    }[status];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (widget.merchant && next != null)
          FilledButton(
            onPressed: busy ? null : () => act(next),
            child: Text(
              {
                'accepted': 'Acceptă comanda',
                'ready': 'Gata de ridicare',
                'collected': 'Verifică codul și finalizează',
              }[next]!,
            ),
          ),
        if (['confirmed', 'accepted', 'ready'].contains(status))
          OutlinedButton(
            onPressed: busy ? null : () => act('cancelled'),
            child: const Text('Anulează comanda'),
          ),
        if (busy)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}
