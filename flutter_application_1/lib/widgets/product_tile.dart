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
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              InkWell(
                onTap: onOpen,
                child: Hero(
                  tag: 'product-image-${product.id}',
                  child: ProductImage(product),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      product.isDemo
                          ? 'DEMO · FĂRĂ PLATĂ'
                          : 'Salvează o porție',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  tooltip: saved ? 'Elimină din favorite' : 'Salvează produsul',
                  onPressed: onFavorite,
                  icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
                ),
              ),
            ],
          ),
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 5),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (product.merchant?['pickup_window'] != null)
                    Row(
                      children: [
                        const Icon(Icons.schedule_outlined, size: 15),
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        money(product.price),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (discount != null) ...[
                        Text(
                          money(original),
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        Text(
                          '−$discount%',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.stock == 0
                        ? 'Momentan epuizat'
                        : product.stock <= 3
                        ? 'Ultimele ${product.stock} disponibile'
                        : '${product.stock} disponibile',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
