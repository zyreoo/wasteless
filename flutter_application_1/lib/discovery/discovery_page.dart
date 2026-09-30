import '../widgets/image_loading.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/live_page.dart';
import 'components.dart';
import 'merchant.dart';
import 'preferences.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key, this.mapFirst = false});
  final bool mapFirst;
  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  late bool mapMode = widget.mapFirst;
  late bool mapVisited = widget.mapFirst;
  String query = '', category = 'Toate';
  bool savedOnly = false;
  DemoMerchant? selected;
  final controller = MapController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void open(DemoMerchant m) =>
      Navigator.pushNamed(context, '/merchant', arguments: m.id);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppPreferences.instance,
    builder: (context, _) {
      final prefs = AppPreferences.instance;
      final merchants = prefs.showDemo
          ? demoMerchants
                .where(
                  (m) =>
                      (category == 'Toate' || m.category == category) &&
                      m.name.toLowerCase().contains(query.toLowerCase()) &&
                      (!savedOnly || prefs.savedMerchants.contains(m.id)),
                )
                .toList()
          : <DemoMerchant>[];
      final active = merchants.contains(selected) ? selected : null;
      return LiveScaffold(
        title: 'În apropierea ta',
        index: 1,
        body: LayoutBuilder(
          builder: (context, bounds) {
            final wide = bounds.maxWidth >= 900;
            final list = ListView(
              padding: const EdgeInsets.all(20),
              children: [
                PageIntro(
                  'Bun de salvat',
                  'Descoperă ceva bun.',
                  'Locuri de cartier. Surprize delicioase. Mai puțină risipă.',
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: prefs.city,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.location_on_outlined),
                          labelText: 'Oraș',
                        ),
                        items: [
                          for (final city in ['București', 'Cluj-Napoca'])
                            DropdownMenuItem(value: city, child: Text(city)),
                        ],
                        onChanged: (city) async {
                          if (city == null) return;
                          await prefs.update(city: city);
                          if (mounted && (wide || mapVisited)) {
                            controller.move(
                              demoMerchants.first.location(city),
                              13,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      tooltip: savedOnly
                          ? 'Toți comercianții'
                          : 'Comercianți salvați',
                      onPressed: () => setState(() => savedOnly = !savedOnly),
                      icon: Icon(
                        savedOnly ? Icons.favorite : Icons.favorite_border,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Caută un comerciant',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final c in [
                      'Toate',
                      'Brutării',
                      'Fructe & legume',
                      'Restaurante',
                    ])
                      ChoiceChip(
                        label: Text(c),
                        selected: category == c,
                        onSelected: (_) => setState(() => category = c),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const DemoNotice(),
                const SizedBox(height: 20),
                if (merchants.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Niciun comerciant pentru selecția ta. Poți schimba filtrele sau activa exemplele din Setări.',
                    ),
                  ),
                for (final m in merchants)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: MerchantCard(
                      m,
                      onOpen: () {
                        if (wide) {
                          setState(() => selected = m);
                          controller.move(m.location(prefs.city), 14);
                        } else {
                          open(m);
                        }
                      },
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/business'),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Ai un business? Descoperă Wasteless'),
                ),
              ],
            );
            final map = Stack(
              children: [
                FlutterMap(
                  mapController: controller,
                  options: MapOptions(
                    initialCenter: demoMerchants.first.location(prefs.city),
                    initialZoom: 13,
                    minZoom: 3,
                    maxZoom: 18,
                    onTap: (_, _) => setState(() => selected = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: const String.fromEnvironment(
                        'MAP_TILE_URL',
                        defaultValue:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      userAgentPackageName: 'ro.wasteless.app',
                      maxZoom: 19,
                      panBuffer: 0,
                    ),
                    MarkerLayer(
                      markers: [
                        for (final m in merchants)
                          Marker(
                            point: m.location(prefs.city),
                            width: 100,
                            height: 48,
                            child: Tooltip(
                              message: '${m.name} — demonstrație',
                              child: GestureDetector(
                                onTap: () => setState(() => selected = m),
                                child: AnimatedContainer(
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 180),
                                  alignment: Alignment.center,
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: active == m ? ink : moss,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${m.price} lei',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      IconButton.filled(
                        tooltip: 'Mărește harta',
                        onPressed: () => controller.move(
                          controller.camera.center,
                          (controller.camera.zoom + 1).clamp(3, 18),
                        ),
                        icon: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      IconButton.filled(
                        tooltip: 'Micșorează harta',
                        onPressed: () => controller.move(
                          controller.camera.center,
                          (controller.camera.zoom - 1).clamp(3, 18),
                        ),
                        icon: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
                if (!wide)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: ActionChip(
                      label: Text('${prefs.city} · DEMO'),
                      avatar: const Icon(Icons.location_on_outlined, size: 16),
                      onPressed: () => setState(() => mapMode = false),
                    ),
                  ),
                if (active != null)
                  Positioned(
                    bottom: 52,
                    left: 16,
                    right: 16,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: SizedBox(
                        width: 340,
                        child: Card(
                          child: ListTile(
                            title: Text(
                              active.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text('${active.price} lei · Demo'),
                            trailing: const Icon(Icons.arrow_forward),
                            onTap: () => open(active),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.white.withValues(alpha: .95),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Locații demonstrative',
                          style: TextStyle(fontSize: 10),
                        ),
                        TextButton(
                          onPressed: () => launchUrl(
                            Uri.parse(
                              'https://www.openstreetmap.org/copyright',
                            ),
                          ),
                          child: const Text(
                            '© OpenStreetMap contributors',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
            return Column(
              children: [
                if (!wide)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.view_agenda_outlined),
                          label: Text('Listă'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.map_outlined),
                          label: Text('Hartă'),
                        ),
                      ],
                      selected: {mapMode},
                      onSelectionChanged: (v) => setState(() {
                        mapMode = v.first;
                        mapVisited = mapVisited || mapMode;
                      }),
                    ),
                  ),
                Expanded(
                  child: wide
                      ? Row(
                          children: [
                            SizedBox(width: 390, child: list),
                            const VerticalDivider(width: 1),
                            Expanded(child: map),
                          ],
                        )
                      : IndexedStack(
                          index: mapMode ? 1 : 0,
                          children: [
                            list,
                            if (mapVisited) map else const SizedBox.expand(),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

class MerchantPage extends StatelessWidget {
  const MerchantPage({super.key, required this.merchant});
  final DemoMerchant merchant;
  @override
  Widget build(BuildContext context) => LiveScaffold(
    title: merchant.name,
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  frameBuilder: softImageFrame,
                  gaplessPlayback: true,
                  merchant.image,
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              PageIntro(
                merchant.category,
                merchant.name,
                '${merchant.area} · ${AppPreferences.instance.city}',
              ),
              const SizedBox(height: 20),
              const DemoNotice(),
              const SizedBox(height: 24),
              Text(
                'Pachet surpriză',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(merchant.description, style: const TextStyle(height: 1.7)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 32,
                runSpacing: 16,
                children: [
                  Text(
                    '${merchant.price} lei',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: Text('Exemplu ridicare: ${merchant.pickup}'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline),
                title: Text('Alergeni & conținut'),
                subtitle: Text(
                  'Verifică ingredientele cu comerciantul înainte de cumpărare. Pachetele surpriză pot varia.',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/home'),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Vezi produsele reale disponibile'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/map'),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Explorează harta demo'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
