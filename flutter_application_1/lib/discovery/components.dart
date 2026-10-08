import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const ink = Color(0xff20291f);
const moss = Color(0xff315c37);
const lime = Color(0xffd9efb4);
const paper = Color(0xfffafaf7);

/// Section label + page title + supporting line, in the shared type scale.
class PageIntro extends StatelessWidget {
  const PageIntro(this.eyebrow, this.title, this.subtitle, {super.key});
  final String eyebrow, title, subtitle;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: theme.textTheme.titleSmall?.copyWith(color: AppColors.brand),
        ),
        const SizedBox(height: Space.xs),
        Text(
          title.replaceAll('\n', ' '),
          style: narrow
              ? theme.textTheme.headlineSmall
              : theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: Space.s),
        Text(
          subtitle,
          style:
              (narrow ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)
                  ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
