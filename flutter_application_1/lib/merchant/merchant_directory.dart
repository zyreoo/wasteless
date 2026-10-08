import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/commerce_service.dart';
import '../models/product.dart';
import '../widgets/live_page.dart';
import '../widgets/product_tile.dart';
import '../discovery/components.dart';
import '../discovery/location.dart';
import '../discovery/preferences.dart';

class MerchantDirectory extends StatefulWidget {
  const MerchantDirectory({
    super.key,
    required this.service,
    this.mapFirst = false,
  });
  final CommerceService service;
  final bool mapFirst;
  @override
  State<MerchantDirectory> createState() => _MerchantDirectoryState();
}

class _MerchantDirectoryState extends State<MerchantDirectory> {
  late bool showMap = widget.mapFirst;
  bool mapVisited = false;
  String query = '';
  final controller = MapController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<(List<Map<String, dynamic>>, List<Product>)> load() async {
    final result = await Future.wait([
      widget.service.merchants(),
      widget.service.products(),
    ]);
    return (
      result[0] as List<Map<String, dynamic>>,
      result[1] as List<Product>,
    );
  }

  void open(
    Map<String, dynamic> merchant,
    List<Product> products,
  ) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LiveScaffold(
        title: merchant['name'] as String,
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PageIntro(
              'Magazin',
              merchant['name'] as String,
              '${merchant['address']}\nRidicare: ${merchant['pickup_window']}',
            ),
            const SizedBox(height: 20),
            if (products.isEmpty)
              const Text('Acest comerciant nu are oferte publicate momentan.'),
            for (final p in products)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined),
                  title: Text(p.name),
                  subtitle: Text('${money(p.price)} · ${p.stock} disponibile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.pushNamed(context, '/product', arguments: p.id),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  void preview(Map<String, dynamic> merchant, List<Product> products) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (products.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      height: 150,
                      child: ProductImage(products.first),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  merchant['name'] as String,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(merchant['address'] as String),
                const SizedBox(height: 8),
                Text(
                  '${products.where((p) => p.stock > 0).length} oferte disponibile · Ridicare ${merchant['pickup_window']}',
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    open(merchant, products);
                  },
                  child: const Text('Vezi ofertele'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LiveScaffold(
    title: 'Explorează',
    index: 1,
    body: LoadPanel<(List<Map<String, dynamic>>, List<Product>)>(
      load: load,
      builder: (data, reload) => LayoutBuilder(
        builder: (context, bounds) {
          final shops = data.$1
              .where(
                (m) => '${m['name']} ${m['address']}'.toLowerCase().contains(
                  query.toLowerCase(),
                ),
              )
              .toList();
          // Nearest shop first, from the user's location or the city centre.
          final reference =
              NearbyLocation.instance.here ??
              cityCenter(AppPreferences.instance.city);
          double? km(Map<String, dynamic> m) {
            final point = shopPoint(m);
            return point == null ? null : distanceKm(reference, point);
          }

          shops.sort(
            (a, b) =>
                (km(a) ?? double.infinity).compareTo(km(b) ?? double.infinity),
          );
          final wide = bounds.maxWidth >= 900;
          final list = ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const PageIntro(
                'În apropiere',
                'Găsește oferte\nlângă tine',
                'Descoperă ofertele și alege intervalul de ridicare potrivit.',
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Comerciant sau adresă',
                ),
                onChanged: (v) => setState(() => query = v),
              ),
              TextButton.icon(
                onPressed: reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizează ofertele'),
              ),
              if (shops.isEmpty)
                const Text('Niciun magazin pentru această căutare.'),
              for (final m in shops)
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: ShopAvatar(imageUrl: m['image_url'] as String?),
                    title: Text(m['name'] as String),
                    subtitle: Text(
                      '${km(m) == null ? '' : '${distanceLabel(km(m)!)} · '}${m['address']}\n${data.$2.where((p) => p.merchantId == m['id'] && p.stock > 0).length} oferte în stoc · ${m['pickup_window']}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => open(
                      m,
                      data.$2.where((p) => p.merchantId == m['id']).toList(),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/business'),
                icon: const Icon(Icons.storefront),
                label: const Text('Spațiul comerciantului'),
              ),
            ],
          );
          final map = Stack(
            children: [
              FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: data.$1.isEmpty
                      ? const LatLng(44.435, 26.102)
                      : LatLng(
                          (data.$1.first['latitude'] as num).toDouble(),
                          (data.$1.first['longitude'] as num).toDouble(),
                        ),
                  initialZoom: 13,
                  minZoom: 3,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'ro.wasteless.app',
                    panBuffer: 0,
                  ),
                  MarkerLayer(
                    markers: [
                      for (final m in shops)
                        Marker(
                          point: LatLng(
                            (m['latitude'] as num).toDouble(),
                            (m['longitude'] as num).toDouble(),
                          ),
                          width: 64,
                          height: 64,
                          child: IconButton.filled(
                            tooltip: m['name'] as String,
                            onPressed: () => preview(
                              m,
                              data.$2
                                  .where((p) => p.merchantId == m['id'])
                                  .toList(),
                            ),
                            icon: const Icon(Icons.storefront),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ColoredBox(
                  color: Colors.white,
                  child: TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                    ),
                    child: const Text('© OpenStreetMap contributors'),
                  ),
                ),
              ),
            ],
          );
          return Column(
            children: [
              if (!wide)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Listă')),
                      ButtonSegment(value: true, label: Text('Hartă')),
                    ],
                    selected: {showMap},
                    onSelectionChanged: (s) => setState(() {
                      showMap = s.first;
                      mapVisited = mapVisited || showMap;
                    }),
                  ),
                ),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          SizedBox(width: 390, child: list),
                          Expanded(child: map),
                        ],
                      )
                    : IndexedStack(
                        index: showMap ? 1 : 0,
                        children: [
                          list,
                          if (mapVisited || showMap)
                            map
                          else
                            const SizedBox.expand(),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
