import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../services/commerce_service.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/live_page.dart';
import '../widgets/product_tile.dart';
import '../discovery/components.dart';
import '../pages/live_orders_page.dart';
import 'order_actions.dart';

/// A picked photo: its bytes and MIME type, or null when the picker was closed.
typedef PickedPhoto = ({List<int> bytes, String contentType});

/// Opens the platform file picker for a JPEG, PNG or WebP image.
Future<PickedPhoto?> pickShopPhoto() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
  );
  if (file == null) return null;
  final type = switch (file.extension?.toLowerCase()) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
  return (bytes: await file.readAsBytes(), contentType: type);
}

class MerchantDashboard extends StatefulWidget {
  const MerchantDashboard({
    super.key,
    required this.service,
    this.pickPhoto = pickShopPhoto,
  });
  final CommerceService service;
  final Future<PickedPhoto?> Function() pickPhoto;
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

  Future<void> changePhoto() async {
    final photo = await widget.pickPhoto();
    if (photo == null || !mounted) return;
    if (photo.bytes.length > 2 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imaginea poate avea cel mult 2 MB.')),
      );
      return;
    }
    await run(
      () => widget.service.uploadShopPhoto(photo.bytes, photo.contentType),
    );
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
            padding: const EdgeInsets.all(Space.xl),
            children: [
              if (merchant == null)
                PageIntro(
                  'Comerciant · mediu de test',
                  merchant?['name'] as String? ?? 'Afacerea ta începe aici.',
                  'Date sincronizate între conturi. Ofertele sunt fictive, iar comenzile nu implică plăți sau ridicări reale.',
                ),
              if (merchant != null) ...[
                Row(
                  children: [
                    ShopAvatar(
                      imageUrl: merchant['image_url'] as String?,
                      size: 56,
                    ),
                    const SizedBox(width: Space.l),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: Space.m,
                            runSpacing: Space.s,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                merchant['name'] as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              if (merchant['status'] == 'pending')
                                const Pill(
                                  'În verificare',
                                  tone: PillTone.warning,
                                )
                              else if (merchant['status'] == 'rejected')
                                const Pill('Neaprobat', tone: PillTone.error),
                              const Pill('Mod demo', tone: PillTone.neutral),
                            ],
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            '${merchant['address']} · Ridicare ${merchant['pickup_window']}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (merchant['status'] == 'pending' ||
                    merchant['status'] == 'rejected') ...[
                  const SizedBox(height: Space.l),
                  DecoratedBox(
                    key: const ValueKey('approval-notice'),
                    decoration: BoxDecoration(
                      color: merchant['status'] == 'pending'
                          ? AppColors.warningSoft
                          : AppColors.errorSoft,
                      borderRadius: BorderRadius.circular(Radii.m),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(Space.m),
                      child: InfoRow(
                        icon: Icons.verified_outlined,
                        text: merchant['status'] == 'pending'
                            ? 'Magazinul tău este în verificare. Poți pregăti ofertele de acum; clienții le văd după aprobare.'
                            : 'Magazinul nu a fost aprobat. Ofertele nu sunt vizibile clienților.',
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: Space.l),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => edit(merchant, profile: true),
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: Text(
                      merchant == null
                          ? 'Creează profil comerciant'
                          : 'Editează profilul',
                    ),
                  ),
                  if (merchant != null)
                    OutlinedButton.icon(
                      key: const ValueKey('shop-photo'),
                      onPressed: busy ? null : changePhoto,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(
                        merchant['image_url'] == null
                            ? 'Adaugă fotografia magazinului'
                            : 'Schimbă fotografia',
                      ),
                    ),
                  if (merchant?['image_url'] != null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => run(widget.service.removeShopPhoto),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Elimină fotografia'),
                    ),
                  TextButton.icon(
                    onPressed: busy ? null : () => run(() async {}),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualizează'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/home'),
                    child: const Text('Vezi ca un client'),
                  ),
                ],
              ),
              if (merchant != null) ...[
                const SizedBox(height: Space.xl),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.l),
                    child: Row(
                      children: [
                        _Stat(value: '$active', label: 'Comenzi active'),
                        const _StatDivider(),
                        _Stat(value: '${products.length}', label: 'Oferte'),
                        const _StatDivider(),
                        _Stat(
                          value: money(revenue),
                          label: 'Ridicat (simulat)',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Space.xl),
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
                  if (products.isNotEmpty)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (final (i, p) in products.indexed) ...[
                            if (i > 0) const Divider(),
                            Padding(
                              padding: const EdgeInsets.all(Space.l),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      Radii.s,
                                    ),
                                    child: SizedBox(
                                      width: 56,
                                      child: ProductImage(
                                        Product.fromJson(
                                          Map<String, dynamic>.from(p),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: Space.l),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p['name'],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        const SizedBox(height: 2),
                                        Wrap(
                                          spacing: Space.s,
                                          runSpacing: Space.xs,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              '${money(p['price'])} · ${p['stock']} disponibile',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                            Pill(
                                              p['active'] == true
                                                  ? 'Publicată'
                                                  : 'Ascunsă',
                                              tone: p['active'] == true
                                                  ? PillTone.success
                                                  : PillTone.neutral,
                                            ),
                                          ],
                                        ),
                                        Wrap(
                                          children: [
                                            TextButton(
                                              onPressed: busy
                                                  ? null
                                                  : () => edit(
                                                      Map<String, dynamic>.from(
                                                        p,
                                                      ),
                                                    ),
                                              child: const Text(
                                                'Editează / stoc',
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: busy
                                                  ? null
                                                  : () => run(
                                                      () => widget.service
                                                          .availability(
                                                            p['id'] as int,
                                                            p['active'] != true,
                                                          ),
                                                    ),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.textSecondary,
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
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ] else ...[
                  if (orders.isEmpty)
                    const Text(
                      'Comenzile clienților apar aici. Poți testa cu alt cont sau din „Vezi ca un client”.',
                    ),
                  if (orders.isNotEmpty)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, o) in orders.indexed) ...[
                            if (i > 0) const Divider(),
                            Padding(
                              padding: const EdgeInsets.all(Space.l),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: Space.s,
                                    runSpacing: Space.xs,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'Comanda #${o['id']}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      StatusPill(o['status'] as String),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${orderDate(o['created_at'])} · ${money(o['total_price'])}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(height: Space.s),
                                  for (final line in o['order_items'])
                                    Text(
                                      '${line['quantity']} × ${line['product_name']}',
                                    ),
                                  if (o['cancellation_reason'] != null)
                                    Text(
                                      'Motiv: ${o['cancellation_reason']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  const SizedBox(height: Space.m),
                                  OrderActions(
                                    order: Map<String, dynamic>.from(o),
                                    service: widget.service,
                                    merchant: true,
                                    reload: reload,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
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

  /// Pickup day relative to today: null = no date (the shop's usual window).
  int? pickupDay;
  final pickupFrom = TextEditingController(text: '19:00');
  final pickupTo = TextEditingController(text: '20:00');
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
    final start = parseTime(widget.data?['pickup_start']);
    final end = parseTime(widget.data?['pickup_end']);
    if (start != null && end != null) {
      final day = DateUtils.dateOnly(start)
          .difference(DateUtils.dateOnly(DateTime.now()))
          .inDays;
      if (day >= 0 && day <= 2) {
        pickupDay = day;
        String hhmm(DateTime t) =>
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        pickupFrom.text = hhmm(start);
        pickupTo.text = hhmm(end);
      }
    }
  }

  static DateTime? _at(int day, String hhmm) {
    final m = RegExp(r'^([01]?\d|2[0-3])[:.]([0-5]\d)$')
        .firstMatch(hhmm.trim());
    if (m == null) return null;
    final today = DateUtils.dateOnly(DateTime.now());
    return DateTime(
      today.year,
      today.month,
      today.day + day,
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
    );
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    pickupFrom.dispose();
    pickupTo.dispose();
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
        final day = pickupDay;
        if (day != null) {
          final start = _at(day, pickupFrom.text)!;
          final end = _at(day, pickupTo.text)!;
          data['pickup_start'] = start.toUtc().toIso8601String();
          data['pickup_end'] = end.toUtc().toIso8601String();
        }
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
              if (!widget.profile) ...[
                const SizedBox(height: Space.l),
                DropdownButtonFormField<int?>(
                  key: const ValueKey('pickup-day'),
                  initialValue: pickupDay,
                  decoration: const InputDecoration(
                    labelText: 'Ziua ridicării',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('Intervalul obișnuit al magazinului'),
                    ),
                    DropdownMenuItem(value: 0, child: Text('Azi')),
                    DropdownMenuItem(value: 1, child: Text('Mâine')),
                    DropdownMenuItem(value: 2, child: Text('Poimâine')),
                  ],
                  onChanged: busy ? null : (v) => setState(() => pickupDay = v),
                ),
                if (pickupDay != null) ...[
                  const SizedBox(height: Space.l),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('pickup-from'),
                          controller: pickupFrom,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'De la (HH:MM)',
                          ),
                          validator: (v) =>
                              _at(0, v ?? '') == null ? 'Ex.: 19:00' : null,
                        ),
                      ),
                      const SizedBox(width: Space.m),
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('pickup-to'),
                          controller: pickupTo,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'Până la (HH:MM)',
                          ),
                          validator: (v) {
                            final day = pickupDay ?? 0;
                            final from = _at(day, pickupFrom.text);
                            final to = _at(day, v ?? '');
                            if (to == null) return 'Ex.: 20:00';
                            if (from != null && !to.isAfter(from)) {
                              return 'După ora de început';
                            }
                            if (!to.isAfter(DateTime.now())) {
                              return 'Intervalul s-a încheiat';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
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

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 40, child: VerticalDivider(width: 1));
}
