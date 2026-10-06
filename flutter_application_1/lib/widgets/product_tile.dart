import 'image_loading.dart';

import 'package:flutter/material.dart';

import '../models/product.dart';

class ProductImage extends StatelessWidget {
  const ProductImage(this.product, {super.key});
  final Product product;
  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(product.image ?? '');
    final name = product.name.toLowerCase();
    final demoImage =
        const [
          'assets/demo/apples.webp',
          'assets/demo/pears.webp',
          'assets/demo/rescue-bag.webp',
        ].contains(product.image)
        ? product.image
        : ['para', 'pară', 'pere'].contains(name)
        ? 'assets/demo/pears.webp'
        : ['mar', 'măr', 'mere'].contains(name)
        ? 'assets/demo/apples.webp'
        : null;
    final fallback = ColoredBox(
      color: const Color(0xffe8ede5),
      child: Center(
        child: Icon(
          Icons.restaurant_outlined,
          size: 40,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
    return AspectRatio(
      aspectRatio: 1.6,
      child: uri?.scheme == 'https'
          ? Image.network(
              frameBuilder: softImageFrame,
              gaplessPlayback: true,
              uri.toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => fallback,
              excludeFromSemantics: true,
            )
          : demoImage == null
          ? fallback
          : Image.asset(
              frameBuilder: softImageFrame,
              gaplessPlayback: true,
              demoImage,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => fallback,
              excludeFromSemantics: true,
            ),
    );
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.saved,
    required this.onFavorite,
    required this.onOpen,
  });
  final Product product;
  final bool saved;
  final VoidCallback? onFavorite;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final original = product.originalPrice;
    final discount = original != null && original > product.price
        ? ((1 - product.price / original) * 100).round()
        : null;
    final stockColor = product.stock == 0
        ? theme.colorScheme.error
        : product.stock <= 3
        ? const Color(0xFF92400E)
        : theme.colorScheme.onSurfaceVariant;
    Widget details(bool bounded) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Text(
            product.merchant?['name'] as String? ??
                product.category ??
                'Wasteless',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          if (product.merchant?['pickup_window'] != null)
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ridicare ${product.merchant!['pickup_window']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          // In a grid every card has the same height: keep price and stock on
          // one baseline across the row instead of leaving a blank tail.
          if (bounded) const Spacer() else const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                money(product.price),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (discount != null)
                Text(
                  money(original),
                  style: theme.textTheme.bodySmall?.copyWith(
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                product.stock == 0
                    ? Icons.remove_shopping_cart_outlined
                    : Icons.inventory_2_outlined,
                size: 14,
                color: stockColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  product.stock == 0
                      ? 'Momentan epuizat'
                      : product.stock <= 3
                      ? 'Ultimele ${product.stock} disponibile'
                      : '${product.stock} disponibile',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: stockColor,
                    fontWeight: product.stock <= 3
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Stack(
        children: [
          InkWell(
            onTap: onOpen,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bounded = constraints.hasBoundedHeight;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Hero(
                          tag: 'product-image-${product.id}',
                          child: Opacity(
                            opacity: product.stock == 0 ? .55 : 1,
                            child: ProductImage(product),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _Pill(
                            product.isDemo
                                ? 'DEMO · FĂRĂ PLATĂ'
                                : 'Salvează o porție',
                            background: theme.colorScheme.surface,
                            foreground: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (discount != null)
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: _Pill(
                              '−$discount%',
                              background: const Color(0xFFD9EFB4),
                              foreground: const Color(0xFF31572C),
                              large: true,
                            ),
                          ),
                      ],
                    ),
                    if (bounded)
                      Expanded(child: details(true))
                    else
                      details(false),
                  ],
                );
              },
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filledTonal(
              tooltip: saved ? 'Elimină din favorite' : 'Salvează produsul',
              onPressed: onFavorite,
              icon: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  child: child,
                ),
                child: Icon(
                  saved ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey(saved),
                  color: saved ? const Color(0xFFC0392B) : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
    this.text, {
    required this.background,
    required this.foreground,
    this.large = false,
  });
  final String text;
  final Color background, foreground;
  final bool large;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 10, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: large ? 13 : 10,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    ),
  );
}
