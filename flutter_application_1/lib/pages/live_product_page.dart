import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../services/commerce_service.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/live_page.dart';
import '../widgets/product_tile.dart';

class LiveProductPage extends StatefulWidget {
  const LiveProductPage({super.key, required this.id, required this.service});
  final int id;
  final CommerceService service;
  @override
  State<LiveProductPage> createState() => _LiveProductPageState();
}

class _LiveProductPageState extends State<LiveProductPage> {
  int quantity = 1;
  bool busy = false;
  bool? saved;
  Future<Product> load() async {
    final results = await Future.wait([
      widget.service.products(saved: true),
      widget.service.product(widget.id),
    ]);
    final favorites = results[0] as List<Product>;
    saved = favorites.any((p) => p.id == widget.id);
    return results[1] as Product;
  }

  Future<void> toggleFavorite() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final existing =
          saved ??
          (await widget.service.products(saved: true))
              .any((p) => p.id == widget.id);
      await widget.service.favorite(widget.id, !existing);
      if (mounted) setState(() => saved = !existing);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AuthController.message(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> add() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.service.add(widget.id, quantity);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Produs adăugat în coș')));
        await Navigator.pushNamed(context, '/cart');
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
    title: 'Ofertă',
    body: LoadPanel<Product>(
      load: load,
      errorTitle: 'Nu am putut încărca oferta',
      loading: const _ProductSkeleton(),
      builder: (p, reload) => LayoutBuilder(
        builder: (context, constraints) {
          final theme = Theme.of(context);
          final wide = constraints.maxWidth >= 860;
          final original = p.originalPrice;
          final discount = original != null && original > p.price
              ? ((1 - p.price / original) * 100).round()
              : null;
          final merchant = p.merchant;
          final soldOut = p.stock == 0;
          final picture = Hero(
            tag: 'product-image-${p.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.l),
              child: ProductImage(p, aspectRatio: wide ? 4 / 3 : 1.6),
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (merchant?['name'] != null)
                Text(
                  merchant!['name'] as String,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.brand,
                  ),
                ),
              const SizedBox(height: Space.xs),
              Text(p.name, style: theme.textTheme.headlineMedium),
              const SizedBox(height: Space.l),
              Wrap(
                spacing: Space.m,
                runSpacing: Space.s,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    money(p.price),
                    style: theme.textTheme.displaySmall?.copyWith(fontSize: 30),
                  ),
                  if (discount != null) ...[
                    Text(
                      money(original),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    Pill('Economisești $discount%', tone: PillTone.accent),
                  ],
                ],
              ),
              const SizedBox(height: Space.xl),
              const Divider(),
              const SizedBox(height: Space.m),
              if (p.pickupLabel != null)
                InfoRow(
                  icon: Icons.schedule_outlined,
                  text: 'Ridicare: ${p.pickupLabel}',
                ),
              if (merchant?['address'] != null)
                InfoRow(
                  icon: Icons.place_outlined,
                  text: merchant!['address'] as String,
                ),
              if (p.allergens != null)
                InfoRow(
                  icon: Icons.health_and_safety_outlined,
                  text: 'Alergeni: ${p.allergens}',
                ),
              InfoRow(
                icon: soldOut
                    ? Icons.remove_shopping_cart_outlined
                    : Icons.inventory_2_outlined,
                text: soldOut
                    ? 'Stoc epuizat'
                    : p.stock <= 3
                    ? 'Ultimele ${p.stock} disponibile'
                    : '${p.stock} disponibile',
              ),
              if (p.description?.isNotEmpty == true) ...[
                const SizedBox(height: Space.l),
                Text(
                  p.description!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: Space.xl),
              Builder(
                builder: (context) {
                  final stepper = QuantityStepper(
                    value: quantity,
                    onDecrement: busy || quantity <= 1
                        ? null
                        : () => setState(() => quantity--),
                    onIncrement: busy || quantity >= p.stock || quantity >= 99
                        ? null
                        : () => setState(() => quantity++),
                  );
                  final cta = FilledButton.icon(
                    onPressed: busy || p.stock < quantity ? null : add,
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: Text(
                      busy
                          ? 'Se adaugă…'
                          : soldOut
                          ? 'Stoc epuizat'
                          : 'Adaugă în coș',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                  final favorite = IconButton.outlined(
                    tooltip: saved == true
                        ? 'Elimină din favorite'
                        : 'Salvează produsul',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      side: const BorderSide(color: AppColors.borderStrong),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.m),
                      ),
                    ),
                    onPressed: busy ? null : toggleFavorite,
                    icon: Icon(
                      saved == true ? Icons.favorite : Icons.favorite_border,
                      color: saved == true ? AppColors.favorite : null,
                    ),
                  );
                  // Phones: the main action gets its own full-width row.
                  if (constraints.maxWidth < 480) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [stepper, const Spacer(), favorite]),
                        const SizedBox(height: Space.m),
                        cta,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      stepper,
                      const SizedBox(width: Space.m),
                      Expanded(child: cta),
                      const SizedBox(width: Space.s),
                      favorite,
                    ],
                  );
                },
              ),
              const SizedBox(height: Space.m),
              Text(
                p.isDemo
                    ? 'Ofertă demonstrativă: comanda testează fluxul, fără plată sau ridicare reală.'
                    : 'Plătești la ridicare, direct la magazin.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          );
          return SingleChildScrollView(
            padding: EdgeInsets.all(wide ? Space.xxl : Space.l),
            child: PageWidth(
              maxWidth: wide ? 1100 : 640,
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 11, child: picture),
                        const SizedBox(width: Space.x3),
                        Expanded(flex: 9, child: details),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        picture,
                        const SizedBox(height: Space.xl),
                        details,
                      ],
                    ),
            ),
          );
        },
      ),
    ),
  );
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 860;
      const picture = AspectRatio(
        aspectRatio: 4 / 3,
        child: SkeletonBox(radius: Radii.l),
      );
      const details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 120, height: 14),
          SizedBox(height: Space.s),
          SkeletonBox(width: 280, height: 28),
          SizedBox(height: Space.l),
          SkeletonBox(width: 160, height: 32),
          SizedBox(height: Space.xl),
          SkeletonBox(width: 240),
          SizedBox(height: Space.m),
          SkeletonBox(width: 200),
          SizedBox(height: Space.m),
          SkeletonBox(width: 220),
        ],
      );
      return Semantics(
        label: 'Se încarcă oferta',
        child: ExcludeSemantics(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(wide ? Space.xxl : Space.l),
            child: PageWidth(
              maxWidth: 1100,
              child: wide
                  ? const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 11, child: picture),
                        SizedBox(width: Space.x3),
                        Expanded(flex: 9, child: details),
                      ],
                    )
                  : const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        picture,
                        SizedBox(height: Space.xl),
                        details,
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );
}
