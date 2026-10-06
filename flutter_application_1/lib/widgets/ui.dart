import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Brand mark: leaf tile plus wordmark.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 18});
  final double size;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: size + 10,
        height: size + 10,
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(Radii.s),
        ),
        child: Icon(Icons.eco, size: size, color: AppColors.accent),
      ),
      const SizedBox(width: Space.s + 2),
      Text(
        'Wasteless',
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AppColors.text,
        ),
      ),
    ],
  );
}

enum PillTone { neutral, brand, accent, success, warning, error }

/// Small rounded label for discounts, statuses and stock.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone = PillTone.neutral, this.icon});
  final String text;
  final PillTone tone;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      PillTone.neutral => (AppColors.surfaceMuted, AppColors.textSecondary),
      PillTone.brand => (AppColors.brandSoft, AppColors.brand),
      PillTone.accent => (AppColors.accent, AppColors.onAccent),
      PillTone.success => (AppColors.successSoft, AppColors.success),
      PillTone.warning => (AppColors.warningSoft, AppColors.warning),
      PillTone.error => (AppColors.errorSoft, AppColors.error),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: foreground),
              const SizedBox(width: Space.xs),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Muted block used to sketch content while it loads.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = Radii.s,
  });
  final double? width;
  final double height;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Rows of placeholder lines for list screens (cart, orders).
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 4, this.thumbnail = true});
  final int rows;
  final bool thumbnail;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Se încarcă',
    child: ExcludeSemantics(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Space.xl),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 180, height: 24),
                  const SizedBox(height: Space.xl),
                  for (var i = 0; i < rows; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.l),
                      child: Row(
                        children: [
                          if (thumbnail) ...[
                            const SkeletonBox(
                              width: 64,
                              height: 48,
                              radius: Radii.s,
                            ),
                            const SizedBox(width: Space.l),
                          ],
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonBox(width: 220),
                                SizedBox(height: Space.s),
                                SkeletonBox(width: 140, height: 12),
                              ],
                            ),
                          ),
                          const SkeletonBox(width: 64),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Page title with optional supporting line, placed at the top of content.
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MediaQuery.sizeOf(context).width < 600
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.headlineMedium,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    subtitle!,
                    style:
                        (MediaQuery.sizeOf(context).width < 600
                                ? theme.textTheme.bodyMedium
                                : theme.textTheme.bodyLarge)
                            ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small uppercase-free section label used between groups of content.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.m),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Compact −/value/+ control with an outline, used for quantities.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    this.decrementTooltip = 'Scade cantitatea',
    this.decrementIcon = Icons.remove,
  });
  final int value;
  final VoidCallback? onDecrement, onIncrement;
  final String decrementTooltip;
  final IconData decrementIcon;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.borderStrong),
      borderRadius: BorderRadius.circular(Radii.m),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: decrementTooltip,
          onPressed: onDecrement,
          icon: Icon(decrementIcon, size: 18),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        IconButton(
          tooltip: 'Crește cantitatea',
          onPressed: onIncrement,
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    ),
  );
}
