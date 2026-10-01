import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../services/commerce_service.dart';
import '../models/product.dart';
import '../widgets/live_page.dart';
import '../discovery/components.dart';
import '../pages/live_orders_page.dart';
import 'order_actions.dart';

class MerchantDashboard extends StatefulWidget {
  const MerchantDashboard({super.key, required this.service});
  final CommerceService service;
  @override
  State<MerchantDashboard> createState() => _MerchantDashboardState();
}

class _MerchantDashboardState extends State<MerchantDashboard> {
  late Future<Map<String, dynamic>> future = widget.service.dashboard();
  int tab = 1;
  bool selectedInitialTab = false;
  bool busy = false;
  Future<void> reload() async {
    final next = widget.service.dashboard();
    setState(() => future = next);
    await next;
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
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

  Future<void> edit(Map<String, dynamic>? data, {bool profile = false}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MerchantEditor(
          service: widget.service,
          data: data,
          profile: profile,
        ),
      ),
    );
    if (saved == true && mounted) await run(() async {});
  }

  @override
  Widget build(BuildContext context) => LiveScaffold(
    title: 'Comerciant',
    body: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => run(() async {}),
                child: Text(
                  '${AuthController.message(snapshot.error!)}\nReîncearcă',
                ),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final merchant = data['merchant'] as Map<String, dynamic>?;
        if (!selectedInitialTab && merchant != null) {
          selectedInitialTab = true;
          tab = merchant['demo_seeded'] == true ? 1 : 0;
        }
        final products = data['products'] as List;
        final orders = data['orders'] as List;
        final active = orders
            .where(
              (o) => ['confirmed', 'accepted', 'ready'].contains(o['status']),
            )
            .length;
        final revenue = orders
            .where((o) => o['status'] == 'collected')
            .fold<double>(
              0,
              (v, o) => v + num.parse('${o['total_price']}').toDouble(),
            );
        return RefreshIndicator(
          onRefresh: () => run(() async {}),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (merchant == null)
                PageIntro(
                  'Comerciant · mediu de test',
                  merchant?['name'] as String? ?? 'Afacerea ta începe aici.',
                  'Date sincronizate între conturi. Ofertele sunt fictive, iar comenzile nu implică plăți sau ridicări reale.',
                ),
              if (merchant != null) ...[
                Text(
                  merchant['name'] as String,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Comenzile și ofertele tale, într-un singur loc. · MOD DEMO',
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => edit(merchant, profile: true),
                    icon: const Icon(Icons.storefront),
                    label: Text(
                      merchant == null
                          ? 'Creează profil comerciant'
                          : 'Editează profilul',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : () => run(() async {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizează'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/home'),
                    child: const Text('Vezi ca un client'),
                  ),
                ],
              ),
              if (merchant != null) ...[
                const SizedBox(height: 16),
                Text(
                  '${merchant['address']}\nRidicare: ${merchant['pickup_window']}',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('$active comenzi active')),
                    Chip(label: Text('${products.length} oferte')),
                    Chip(
                      label: Text('${money(revenue)} · total simulat ridicat'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Oferte'),
                      icon: Icon(Icons.inventory_2_outlined),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Comenzi'),
                      icon: Icon(Icons.receipt_long),
                    ),
                  ],
                  selected: {tab},
                  onSelectionChanged: (v) => setState(() => tab = v.first),
                ),
                const SizedBox(height: 16),
                if (tab == 0) ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : () => edit(null),
                        icon: const Icon(Icons.add),
                        label: const Text('Adaugă ofertă'),
                      ),
                      if (merchant['demo_seeded'] != true)
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => run(widget.service.seedProducts),
                          child: const Text('Adaugă cele 4 produse fictive'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (products.isEmpty)
                    const Text(
                      'Publică prima ofertă sau adaugă produsele fictive pentru test.',
                    ),
                  for (final p in products)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['name'],
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '${money(p['price'])} · ${p['stock']} disponibile · ${p['active'] == true ? 'Publicată' : 'Ascunsă'}',
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () =>
                                            edit(Map<String, dynamic>.from(p)),
                                  child: const Text('Editează / stoc'),
                                ),
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => run(
                                          () => widget.service.availability(
                                            p['id'] as int,
                                            p['active'] != true,
                                          ),
                                        ),
                                  child: Text(
                                    p['active'] == true
                                        ? 'Ascunde oferta'
                                        : 'Publică oferta',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ] else ...[
                  if (orders.isEmpty)
                    const Text(
                      'Comenzile clienților apar aici. Poți testa cu alt cont sau din „Vezi ca un client”.',
                    ),
                  for (final o in orders)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comanda #${o['id']} · ${orderStatus(o['status'])}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '${orderDate(o['created_at'])} · ${money(o['total_price'])}',
                            ),
                            for (final line in o['order_items'])
                              Text(
                                '${line['quantity']} × ${line['product_name']}',
                              ),
                            if (o['cancellation_reason'] != null)
                              Text('Motiv: ${o['cancellation_reason']}'),
                            const SizedBox(height: 12),
                            OrderActions(
                              order: Map<String, dynamic>.from(o),
                              service: widget.service,
                              merchant: true,
                              reload: reload,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ],
          ),
        );
      },
    ),
  );
}

class MerchantEditor extends StatefulWidget {
  const MerchantEditor({
    super.key,
    required this.service,
    this.data,
    this.profile = false,
  });
  final CommerceService service;
  final Map<String, dynamic>? data;
  final bool profile;
  @override
  State<MerchantEditor> createState() => _MerchantEditorState();
}

class _MerchantEditorState extends State<MerchantEditor> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  bool busy = false;
  String image = 'assets/demo/rescue-bag.webp';
  @override
  void initState() {
    super.initState();
    final defaults = widget.profile
        ? {
            'name': 'Atelierul meu · DEMO',
            'address': 'Adresă fictivă: Strada Exemplu 10, București',
            'pickup_window': '18:00–19:00',
            'latitude': '44.435',
            'longitude': '26.102',
          }
        : {
            'name': '',
            'description': 'Produs fictiv pentru simularea fluxului.',
            'price': '19.00',
            'original_price': '55.00',
            'stock': '8',
            'category': 'Brutărie',
            'allergens': 'Gluten, lapte',
          };
    for (final key in defaults.keys) {
      fields[key] = TextEditingController(
        text: '${widget.data?[key] ?? defaults[key]}',
      );
    }
    image = widget.data?['image_path'] as String? ?? image;
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || busy) return;
    setState(() => busy = true);
    try {
      final data = <String, dynamic>{
        for (final e in fields.entries) e.key: e.value.text.trim(),
      };
      if (widget.profile) {
        for (final key in ['latitude', 'longitude']) {
          data[key] = double.parse((data[key] as String).replaceAll(',', '.'));
        }
        await widget.service.saveMerchant(data);
      } else {
        data['stock'] = int.parse(data['stock']);
        for (final key in ['price', 'original_price']) {
          data[key] = (data[key] as String).replaceAll(',', '.');
        }
        data['image_path'] = image;
        await widget.service.saveProduct(data, id: widget.data?['id'] as int?);
      }
      if (mounted) Navigator.pop(context, true);
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
    title: widget.profile ? 'Profil comerciant' : 'Oferta ta',
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'MOD TEST · Datele sunt salvate în backend și vizibile celorlalte conturi. Nu introduce date de plată.',
              ),
              const SizedBox(height: 20),
              for (final e in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: e.value,
                    enabled: !busy,
                    maxLength:
                        {
                          'name': 100,
                          'address': 300,
                          'pickup_window': 100,
                          'description': 2000,
                          'category': 80,
                          'allergens': 500,
                        }[e.key] ??
                        20,
                    minLines: e.key == 'description' ? 2 : 1,
                    maxLines: e.key == 'description' ? 4 : 1,
                    keyboardType:
                        [
                          'price',
                          'original_price',
                          'latitude',
                          'longitude',
                          'stock',
                        ].contains(e.key)
                        ? const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          )
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: const {
                        'name': 'Nume',
                        'address': 'Adresă de ridicare',
                        'pickup_window': 'Interval de ridicare',
                        'latitude': 'Latitudine',
                        'longitude': 'Longitudine',
                        'description': 'Descriere',
                        'price': 'Preț redus (lei)',
                        'original_price': 'Preț inițial (lei)',
                        'stock':
                            'Stoc disponibil (fără cantitățile deja rezervate)',
                        'category': 'Categorie',
                        'allergens': 'Alergeni',
                      }[e.key],
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Completează câmpul.';
                      }
                      if ([
                            'price',
                            'original_price',
                            'latitude',
                            'longitude',
                          ].contains(e.key) &&
                          double.tryParse(v.replaceAll(',', '.')) == null) {
                        return 'Introdu un număr valid.';
                      }
                      if (e.key == 'stock' &&
                          (int.tryParse(v) == null || int.parse(v) < 0)) {
                        return 'Stocul trebuie să fie un număr întreg pozitiv sau zero.';
                      }
                      return null;
                    },
                  ),
                ),
              if (!widget.profile)
                DropdownButtonFormField<String>(
                  initialValue: image,
                  decoration: const InputDecoration(
                    labelText: 'Imagine ilustrativă',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'assets/demo/rescue-bag.webp',
                      child: Text('Pachet surpriză'),
                    ),
                    DropdownMenuItem(
                      value: 'assets/demo/apples.webp',
                      child: Text('Mere'),
                    ),
                    DropdownMenuItem(
                      value: 'assets/demo/pears.webp',
                      child: Text('Pere'),
                    ),
                  ],
                  onChanged: busy ? null : (v) => setState(() => image = v!),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Se salvează…' : 'Salvează în backend'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
