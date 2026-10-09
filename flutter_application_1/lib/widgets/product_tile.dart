import 'image_loading.dart';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// A photo matching a bag's name or category, from the bundled assets.
String? suggestedImage(Product product) {
  final text = '${product.name} ${product.category ?? ''}'.toLowerCase();
  const rules = [
    (['poke'], 'poke'),
    (['sushi'], 'sushi'),
    (['supă', 'supa', 'ciorb'], 'soup'),
    (['vegetarian'], 'veggie-bowl'),
    (['mic dejun'], 'breakfast'),
    (['sandviș', 'sandvis', 'wrap'], 'sandwich'),
    (['la cafea', 'brownie'], 'brownies'),
    (['tort'], 'cake'),
    (['fursec', 'biscui'], 'cookies'),
    (['premium'], 'pastries'),
    (['prăjitur', 'prajitur', 'cofetări', 'cofetari'], 'tarts'),
    (['patiserie', 'croissant'], 'croissants'),
    (['pâine', 'paine', 'brutări', 'brutari'], 'bread'),
    (['salată', 'salata', 'verdeț', 'verdet'], 'greens'),
    (['legume'], 'vegetables'),
    (['gustări', 'gustari'], 'sandwich'),
    (['mâncare gătită', 'mancare gatita'], 'meal'),
    (['cafenea'], 'breakfast'),
  ];
  for (final (words, file) in rules) {
    if (words.any(text.contains)) return 'assets/demo/$file.jpg';
  }
  return null;
}

class ProductImage extends StatelessWidget {
  const ProductImage(this.product, {super.key, this.aspectRatio = 4 / 3});
  final Product product;
  final double aspectRatio;
  @override
  Widget build(BuildContext context) {
    // A shop photo represents its surprise bags; product images are a fallback.
    final shopPhoto = product.merchant?['image_url'] as String?;
    final uri = Uri.tryParse(shopPhoto ?? product.image ?? '');
    final name = product.name.toLowerCase();
    // The generic surprise-bag photo (or no photo) is replaced by one that
    // matches what the bag contains.
    final assetImage =
        product.image == null || product.image == 'assets/demo/rescue-bag.webp'
        ? suggestedImage(product) ?? product.image
        : const [
            'assets/demo/apples.webp',
            'assets/demo/pears.webp',
          ].contains(product.image)
        ? product.image
        : ['para', 'pară', 'pere'].contains(name)
        ? 'assets/demo/pears.webp'
        : ['mar', 'măr', 'mere'].contains(name)
        ? 'assets/demo/apples.webp'
        : null;
    const fallback = ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Icon(
          Icons.restaurant_outlined,
          size: 32,
          color: AppColors.textMuted,
        ),
      ),
    );
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: uri?.scheme == 'https'
          ? Image.network(
              frameBuilder: softImageFrame,
              gaplessPlayback: true,
              uri.toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => fallback,
              excludeFromSemantics: true,
            )
          : assetImage == null
          ? fallback
          : Image.asset(
              frameBuilder: softImageFrame,
              gaplessPlayback: true,
              assetImage,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => fallback,
              excludeFromSemantics: true,
            ),
    );
  }
}

class ProductTile extends StatefulWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.saved,
    required this.onFavorite,
    required this.onOpen,
    this.imageAspect = 4 / 3,
    this.showFavorite = true,
  });
  final Product product;
  final bool saved;
  final VoidCallback? onFavorite;
  final VoidCallback onOpen;

  /// Grids use 4:3; single-column phone lists use a wider 16:10 so more
  /// offers fit on screen.
  final double imageAspect;

  /// Shop pages list offers without the favorite control.
  final bool showFavorite;

  @override
  State<ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<ProductTile> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;
    final original = product.originalPrice;
    final discount = original != null && original > product.price
        ? ((1 - product.price / original) * 100).round()
        : null;
    final soldOut = product.stock == 0;
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final (stockText, stockColor) = soldOut
        ? ('Momentan epuizat', AppColors.error)
        : product.stock <= 3
        ? ('Ultimele ${product.stock}', AppColors.warning)
        : ('${product.stock} disponibile', AppColors.textSecondary);
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: Stack(
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onOpen,
              borderRadius: BorderRadius.circular(Radii.l),
              hoverColor: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.l),
                    child: Stack(
                      children: [
                        Hero(
                          tag: 'product-image-${product.id}',
                          child: AnimatedScale(
                            scale: hovered ? 1.02 : 1,
                            duration: motion,
                            curve: Curves.easeOut,
                            child: Opacity(
                              opacity: soldOut ? .5 : 1,
                              child: ProductImage(
                                product,
                                aspectRatio: widget.imageAspect,
                              ),
                            ),
                          ),
                        ),
                        if (discount != null)
                          Positioned(
                            left: Space.m,
                            bottom: Space.m,
                            child: Pill('−$discount%', tone: PillTone.accent),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.xs,
                      Space.m,
                      Space.xs,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.merchant?['name'] as String? ??
                              product.category ??
                              'Wasteless',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: Space.s),
                        Wrap(
                          spacing: Space.s,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              money(product.price),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (discount != null)
                              Text(
                                money(original),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                        if (product.pickupLabel != null) ...[
                          const SizedBox(height: Space.xs),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: Space.xs + 2),
                              Expanded(
                                child: Text(
                                  'Ridicare ${product.pickupLabel}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          stockText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: stockColor,
                            fontWeight: product.stock <= 3
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.showFavorite)
            Positioned(
              top: Space.s,
              right: Space.s,
              child: _FavoriteButton(
                saved: widget.saved,
                onPressed: widget.onFavorite,
                duration: motion,
              ),
            ),
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.saved,
    required this.onPressed,
    required this.duration,
  });
  final bool saved;
  final VoidCallback? onPressed;
  final Duration duration;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface.withValues(alpha: .94),
    shape: const CircleBorder(),
    elevation: 0,
    child: IconButton(
      tooltip: saved ? 'Elimină din favorite' : 'Salvează produsul',
      onPressed: onPressed,
      iconSize: 20,
      icon: AnimatedSwitcher(
        duration: duration,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween(begin: .6, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
        child: Icon(
          saved ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(saved),
          color: saved ? AppColors.favorite : AppColors.text,
        ),
      ),
    ),
  );
}
