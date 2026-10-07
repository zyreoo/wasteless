import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../models/product.dart';
import '../services/commerce_service.dart';
import '../discovery/location.dart';
import '../discovery/preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/live_page.dart';
import '../widgets/product_tile.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({
    super.key,
    required this.service,
    this.savedOnly = false,
    this.search = false,
    this.location = const DeviceLocation(),
  });
  final CommerceService service;
  final bool savedOnly, search;
  final LocationProvider location;
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  String query = '';
  BrowseMemory? memory;
  bool restored = false;
  String get memoryKey => widget.savedOnly ? 'saved' : 'catalog';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    memory = BrowseMemory.of(context);
    if (!restored) {
      restored = true;
      query = memory?.values['$memoryKey.query'] as String? ?? '';
      selectedCategory = memory?.values['$memoryKey.category'] as String?;
      searchController.text = query;
    }
  }

  String? selectedCategory;
  PickupWhen when = PickupWhen.any;

  /// Discovery groups bags by shop; favourites stay a plain grid.
  bool get shopFirst => !widget.savedOnly && !widget.search;

  @override
  void initState() {
    super.initState();
    NearbyLocation.instance.addListener(relocated);
  }

  void relocated() {
    if (mounted) setState(() {});
  }

  Future<void> useMyLocation() async {
    final found = await NearbyLocation.instance.locate(widget.location);
    if (!found && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nu am putut accesa locația. Afișăm distanțele față de centrul orașului.',
          ),
        ),
      );
    }
  }

  final searchController = TextEditingController();
  @override
  void dispose() {
    NearbyLocation.instance.removeListener(relocated);
    searchController.dispose();
    super.dispose();
  }

  void remember() {
    memory?.values['$memoryKey.query'] = query;
    memory?.values['$memoryKey.category'] = selectedCategory;
  }

  final fallbackBucket = PageStorageBucket();
  final busy = <int>{};
  late final pager = widget.service.productPager();
  Set<int> saved = {};

  /// Favorites are one small list; the catalogue starts with its first page.
  Future<List<Product>> load() async {
    if (widget.savedOnly) {
      final items = await widget.service.products(saved: true);
      saved = items.map((p) => p.id).toSet();
      return items;
    }
    final results = await Future.wait([
      widget.service.products(saved: true),
      pager.refresh(),
    ]);
    saved = results[0].map((p) => p.id).toSet();
    return results[1];
  }

  /// Scrolling loads automatically until a page fails; after that only the
  /// button retries, so errors and 429s never turn into a request loop.
  bool autoLoad = true;
  Future<void> loadMore({bool manual = false}) async {
    if (widget.savedOnly || !pager.hasMore || pager.loading) return;
    if (!manual && !autoLoad) return;
    setState(() => autoLoad = true);
    try {
      await pager.more();
    } catch (e) {
      autoLoad = false;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AuthController.message(e))));
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> toggle(
    Product p,
    bool wasSaved,
    Future<void> Function() reload,
  ) async {
    if (busy.contains(p.id)) return;
    setState(() => busy.add(p.id));
    try {
      await widget.service.favorite(p.id, !wasSaved);
      if (widget.savedOnly) {
        await reload();
      } else if (mounted) {
        // Only the heart changed; refetching every loaded page is wasteful.
        setState(() {
          if (wasSaved) {
            saved.remove(p.id);
          } else {
            saved.add(p.id);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AuthController.message(e))));
      }
    } finally {
      if (mounted) setState(() => busy.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) => LiveScaffold(
    title: widget.savedOnly
        ? 'Favorite'
        : widget.search
        ? 'Caută oferte'
        : 'Descoperă',
    index: widget.savedOnly
        ? 2
        : widget.search
        ? 1
        : 0,
    body: LoadPanel(
      load: load,
      errorTitle: widget.savedOnly
          ? 'Nu am putut încărca favoritele'
          : 'Nu am putut încărca ofertele',
      loading: _CatalogSkeleton(header: !widget.savedOnly),
      builder: (data, reload) {
        // Load-more appends to the pager after this snapshot was taken.
        final all = widget.savedOnly ? data : pager.items;
        final canLoadMore = !widget.savedOnly && pager.hasMore;
        final products = all
            .where(
              (p) =>
                  '${p.name} ${p.merchant?['name'] ?? ''}'
                      .toLowerCase()
                      .contains(query.toLowerCase()) &&
                  (selectedCategory == null ||
                      p.category == selectedCategory) &&
                  (!shopFirst || matchesWhen(p, when)),
            )
            .toList();
        final here = NearbyLocation.instance.here;
        final reference = here ?? cityCenter(AppPreferences.instance.city);
        // Bags grouped by shop, nearest shop first.
        final groups = <Object, List<Product>>{};
        for (final p in products) {
          groups.putIfAbsent(p.merchantId ?? 'other', () => []).add(p);
        }
        double? kmTo(List<Product> bags) {
          final point = shopPoint(bags.first.merchant);
          return point == null ? null : distanceKm(reference, point);
        }

        final shops = groups.values.toList()
          ..sort(
            (a, b) => (kmTo(a) ?? double.infinity).compareTo(
              kmTo(b) ?? double.infinity,
            ),
          );
        final categories = all
            .map((p) => p.category)
            .whereType<String>()
            .where((c) => c.isNotEmpty)
            .toSet();
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final gutter = width >= 600 ? Space.xxl : Space.l;
            final content = (width - gutter * 2).clamp(0.0, 1200.0);
            final side = (width - content) / 2;
            final columns = content >= 1080
                ? 4
                : content >= 760
                ? 3
                : content >= 480
                ? 2
                : 1;
            final imageAspect = columns == 1 ? 1.6 : 4 / 3;
            Widget card(Product p, int index) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : Duration(milliseconds: 220 + (index % 8) * 30),
                curve: Curves.easeOutCubic,
                builder: (_, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - value)),
                    child: child,
                  ),
                ),
                child: ProductTile(
                  key: ValueKey('product-${p.id}'),
                  product: p,
                  imageAspect: imageAspect,
                  saved: saved.contains(p.id),
                  onFavorite: busy.contains(p.id)
                      ? null
                      : () => toggle(p, saved.contains(p.id), reload),
                  onOpen: () async {
                    await Navigator.pushNamed(
                      context,
                      '/product',
                      arguments: p.id,
                    );
                    if (mounted) await reload();
                  },
                ),
              );
            }

            void clearFilters() {
              searchController.clear();
              setState(() {
                query = '';
                selectedCategory = null;
                when = PickupWhen.any;
              });
              remember();
            }

            List<Widget> rows(
              List<Product> bags, {
              double bottom = Space.x3,
            }) => [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 0, side, bottom),
                // Rows of naturally sized cards: no fixed cell height, so no
                // gaps or clipping at any text size.
                sliver: SliverList.separated(
                  itemCount: (bags.length / columns).ceil(),
                  separatorBuilder: (_, _) => const SizedBox(height: Space.xxl),
                  itemBuilder: (_, row) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var c = 0; c < columns; c++) ...[
                        if (c > 0) const SizedBox(width: Space.xl),
                        Expanded(
                          child: row * columns + c < bags.length
                              ? card(bags[row * columns + c], row * columns + c)
                              : const SizedBox(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ];

            final Widget? empty = all.isEmpty
                ? EmptyPanel(
                    widget.savedOnly
                        ? 'Încă nu ai favorite'
                        : 'Nu sunt oferte acum',
                    icon: widget.savedOnly
                        ? Icons.favorite_border
                        : Icons.local_offer_outlined,
                    detail: widget.savedOnly
                        ? 'Apasă inima de pe o ofertă ca să o găsești rapid aici.'
                        : 'Magazinele adaugă oferte pe parcursul zilei. Revino puțin mai târziu.',
                  )
                : products.isEmpty
                ? StatusPanel(
                    icon: Icons.search_off_rounded,
                    title: 'Nicio ofertă găsită',
                    detail: query.isNotEmpty
                        ? 'Nu avem nimic pentru „$query”. Încearcă alt cuvânt sau altă categorie.'
                        : when != PickupWhen.any
                        ? 'Nu sunt pachete pentru intervalul ales. Încearcă „Oricând”.'
                        : 'Nu sunt oferte în această categorie acum.',
                    action: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: Space.s,
                      runSpacing: Space.s,
                      children: [
                        OutlinedButton(
                          onPressed: clearFilters,
                          child: const Text('Șterge filtrele'),
                        ),
                        if (canLoadMore)
                          _LoadMore(
                            loading: pager.loading,
                            label: 'Caută în mai multe oferte',
                            onPressed: () => loadMore(manual: true),
                          ),
                      ],
                    ),
                  )
                : null;

            final theme = Theme.of(context);
            return RefreshIndicator(
              onRefresh: reload,
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (canLoadMore &&
                      n.depth == 0 &&
                      autoLoad &&
                      !pager.loading &&
                      n.metrics.extentAfter < 600) {
                    Future.microtask(loadMore);
                  }
                  return false;
                },
                child: PageStorage(
                  bucket: memory?.bucket ?? fallbackBucket,
                  child: CustomScrollView(
                    key: PageStorageKey('$memoryKey.$columns'),
                    // Header, search and filters scroll away with the
                    // offers so the products get the screen.
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(side, gutter, side, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!widget.savedOnly && !widget.search)
                                PageHeader(
                                  'Mâncare bună, la preț redus',
                                  subtitle: 'Salvăm de la risipă produsele rămase la magazinele din oraș.',
                                  trailing: width >= 600
                                      ? OutlinedButton.icon(
                                          onPressed: () => Navigator.pushNamed(
                                            context,
                                            '/map',
                                          ),
                                          icon: const Icon(
                                            Icons.map_outlined,
                                            size: 18,
                                          ),
                                          label: const Text('Vezi pe hartă'),
                                        )
                                      : IconButton.outlined(
                                          tooltip: 'Vezi pe hartă',
                                          onPressed: () => Navigator.pushNamed(
                                            context,
                                            '/map',
                                          ),
                                          icon: const Icon(Icons.map_outlined),
                                        ),
                                ),
                              if (all.isNotEmpty) ...[
                                TextField(
                                  controller: searchController,
                                  textInputAction: TextInputAction.search,
                                  decoration: InputDecoration(
                                    hintText: widget.savedOnly
                                        ? 'Caută în favorite'
                                        : 'Caută o ofertă sau un produs',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: query.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: 'Șterge căutarea',
                                            onPressed: () {
                                              searchController.clear();
                                              setState(() => query = '');
                                              remember();
                                            },
                                            icon: const Icon(Icons.close),
                                          ),
                                  ),
                                  onChanged: (v) {
                                    setState(() => query = v);
                                    remember();
                                  },
                                ),
                                const SizedBox(height: Space.m),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (all.isNotEmpty &&
                          (shopFirst || categories.isNotEmpty))
                        SliverToBoxAdapter(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: side),
                            child: Row(
                              children: [
                                if (shopFirst) ...[
                                  for (final (option, label) in const [
                                    (PickupWhen.any, 'Oricând'),
                                    (PickupWhen.now, 'Acum'),
                                    (PickupWhen.today, 'Azi'),
                                    (PickupWhen.tomorrow, 'Mâine'),
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: Space.s,
                                      ),
                                      child: ChoiceChip(
                                        key: ValueKey('when-${option.name}'),
                                        avatar: option == PickupWhen.any
                                            ? null
                                            : const Icon(
                                                Icons.schedule_outlined,
                                                size: 16,
                                              ),
                                        label: Text(label),
                                        selected: when == option,
                                        onSelected: (_) =>
                                            setState(() => when = option),
                                      ),
                                    ),
                                  if (categories.isNotEmpty)
                                    const SizedBox(
                                      height: 24,
                                      child: VerticalDivider(width: Space.l),
                                    ),
                                ],
                                if (categories.isNotEmpty)
                                  for (final category in <String?>[
                                    null,
                                    ...categories,
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: Space.s,
                                      ),
                                      child: ChoiceChip(
                                        label: Text(category ?? 'Toate'),
                                        selected: selectedCategory == category,
                                        onSelected: (_) {
                                          setState(
                                            () => selectedCategory = category,
                                          );
                                          remember();
                                        },
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      if (empty != null)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: empty),
                        )
                      else ...[
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            side,
                            Space.l,
                            side,
                            Space.l,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: Wrap(
                              spacing: Space.m,
                              runSpacing: Space.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  shopFirst
                                      ? '${products.length == 1 ? '1 pachet' : '${products.length} pachete'} · ${shops.length == 1 ? '1 magazin' : '${shops.length} magazine'}'
                                      : products.length == 1
                                      ? '1 ofertă'
                                      : '${products.length} oferte',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (shopFirst) ...[
                                  Text(
                                    here == null
                                        ? 'Distanțe față de centrul orașului ${AppPreferences.instance.city}'
                                        : 'Distanțe față de locația ta',
                                    key: const ValueKey('distance-reference'),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (here == null)
                                    NearbyLocation.instance.locating
                                        ? const SizedBox.square(
                                            dimension: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : TextButton.icon(
                                            key: const ValueKey('use-location'),
                                            onPressed: useMyLocation,
                                            icon: const Icon(
                                              Icons.near_me_outlined,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Folosește locația mea',
                                            ),
                                          ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (shopFirst)
                          for (final (i, bags) in shops.indexed) ...[
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                side,
                                i == 0 ? 0 : Space.l,
                                side,
                                Space.l,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: _ShopHeader(
                                  merchant: bags.first.merchant,
                                  km: kmTo(bags),
                                  count: bags.length,
                                ),
                              ),
                            ),
                            ...rows(
                              bags,
                              bottom: i == shops.length - 1 && !canLoadMore
                                  ? Space.x3
                                  : Space.xl,
                            ),
                          ]
                        else
                          ...rows(
                            products,
                            bottom: canLoadMore ? Space.l : Space.x3,
                          ),
                        if (canLoadMore)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: Space.x3),
                              child: Center(
                                child: _LoadMore(
                                  loading: pager.loading,
                                  label: 'Încarcă mai multe oferte',
                                  onPressed: () => loadMore(manual: true),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

/// First-load placeholder shaped like the real header and grid.
class _CatalogSkeleton extends StatelessWidget {
  const _CatalogSkeleton({required this.header});
  final bool header;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final gutter = width >= 600 ? Space.xxl : Space.l;
      final content = (width - gutter * 2).clamp(0.0, 1200.0);
      final columns = content >= 1080
          ? 4
          : content >= 760
          ? 3
          : content >= 480
          ? 2
          : 1;
      return Semantics(
        label: 'Se încarcă ofertele',
        child: ExcludeSemantics(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: (width - content) / 2,
              vertical: gutter,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (header) ...[
                  const SkeletonBox(width: 320, height: 28),
                  const SizedBox(height: Space.s),
                  const SkeletonBox(width: 260),
                  const SizedBox(height: Space.xl),
                ],
                const SkeletonBox(height: 50, radius: Radii.m),
                const SizedBox(height: Space.m),
                const Row(
                  children: [
                    SkeletonBox(width: 64, height: 32, radius: Radii.pill),
                    SizedBox(width: Space.s),
                    SkeletonBox(width: 84, height: 32, radius: Radii.pill),
                    SizedBox(width: Space.s),
                    SkeletonBox(width: 72, height: 32, radius: Radii.pill),
                  ],
                ),
                const SizedBox(height: Space.xl + Space.xl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var c = 0; c < columns; c++) ...[
                      if (c > 0) const SizedBox(width: Space.xl),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 4 / 3,
                              child: SkeletonBox(radius: Radii.l),
                            ),
                            SizedBox(height: Space.m),
                            SkeletonBox(width: 170, height: 16),
                            SizedBox(height: Space.s),
                            SkeletonBox(width: 110, height: 12),
                            SizedBox(height: Space.m),
                            SkeletonBox(width: 80, height: 18),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _LoadMore extends StatelessWidget {
  const _LoadMore({
    required this.loading,
    required this.label,
    required this.onPressed,
  });
  final bool loading;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => loading
      ? const SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        )
      : OutlinedButton(
          key: const ValueKey('load-more'),
          onPressed: onPressed,
          child: Text(label),
        );
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({
    required this.merchant,
    required this.km,
    required this.count,
  });
  final Map<String, dynamic>? merchant;
  final double? km;
  final int count;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = [
      if (km != null) distanceLabel(km!),
      if (merchant?['address'] != null) merchant!['address'] as String,
    ].join(' · ');
    return Semantics(
      header: true,
      child: Row(
        children: [
          ShopAvatar(imageUrl: merchant?['image_url'] as String?, size: 44),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchant?['name'] as String? ?? 'Alte oferte',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.m),
          Text(
            count == 1 ? '1 pachet' : '$count pachete',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
