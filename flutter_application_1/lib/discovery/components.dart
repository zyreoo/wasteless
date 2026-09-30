import '../widgets/image_loading.dart';

import 'package:flutter/material.dart';

import 'merchant.dart';
import 'preferences.dart';

const ink = Color(0xff20291f);
const moss = Color(0xff315c37);
const lime = Color(0xffd9efb4);
const paper = Color(0xfffafaf7);

class PageIntro extends StatelessWidget {
  const PageIntro(this.eyebrow, this.title, this.subtitle, {super.key});
  final String eyebrow, title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
          color: moss,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        title,
        style: TextStyle(
          fontSize: MediaQuery.sizeOf(context).width < 600 ? 26 : 36,
          height: 1.2,
          letterSpacing: -0.6,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      const SizedBox(height: 12),
      Text(subtitle, style: const TextStyle(fontSize: 15, height: 1.6)),
    ],
  );
}

class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xfff4eddc),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Demo: comercianți, locații și oferte ilustrative. Nu se pot comanda.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class MerchantCard extends StatefulWidget {
  const MerchantCard(
    this.merchant, {
    super.key,
    required this.onOpen,
    this.compact = false,
  });
  final DemoMerchant merchant;
  final VoidCallback onOpen;
  final bool compact;
  @override
  State<MerchantCard> createState() => _MerchantCardState();
}

class _MerchantCardState extends State<MerchantCard> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final m = widget.merchant;
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, hovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xffe4e7df)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: hovered ? .08 : .025),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Image.asset(
                    frameBuilder: softImageFrame,
                    gaplessPlayback: true,
                    m.image,
                    height: widget.compact ? 115 : 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: lime,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '−${m.discount}% · DEMO',
                        style: const TextStyle(
                          color: ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ListenableBuilder(
                      listenable: AppPreferences.instance,
                      builder: (context, _) {
                        final saved = AppPreferences.instance.savedMerchants
                            .contains(m.id);
                        return IconButton.filledTonal(
                          tooltip: saved
                              ? 'Elimină comerciantul salvat'
                              : 'Salvează comerciantul',
                          onPressed: () =>
                              AppPreferences.instance.toggleSaved(m.id),
                          icon: Icon(
                            saved ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.category,
                      style: const TextStyle(
                        fontSize: 11,
                        color: moss,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      m.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ridicare ${m.pickup}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${m.price} lei',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: moss,
                          ),
                        ),
                        Text(
                          '${m.originalPrice} lei',
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            fontSize: 13,
                          ),
                        ),
                        const Text(
                          'Pachet surpriză',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
