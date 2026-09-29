import 'package:flutter/material.dart';

import '../models/product.dart';

class ProductImage extends StatelessWidget {
  const ProductImage(this.product, {super.key});
  final Product product;
  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(product.image ?? '');
    final demoImage = product.name.toLowerCase().contains('par')
        ? 'assets/demo/pears.png'
        : 'assets/demo/apples.png';
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
              uri.toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => fallback,
              excludeFromSemantics: true,
            )
          : Image.asset(
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
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    margin: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProductImage(product),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  money(product.price),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  product.stock > 0
                      ? '${product.stock} disponibile'
                      : 'Stoc epuizat',
                ),
              ),
              IconButton(
                tooltip: saved ? 'Elimină din favorite' : 'Salvează produsul',
                onPressed: onFavorite,
                icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
