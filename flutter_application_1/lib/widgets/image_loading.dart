import 'package:flutter/material.dart';

/// Reserve the image's layout and fade in its first decoded frame only.
Widget softImageFrame(
  BuildContext context,
  Widget child,
  int? frame,
  bool synchronouslyLoaded,
) {
  if (synchronouslyLoaded) return child;
  return ColoredBox(
    color: const Color(0xffe8ede5),
    child: AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: child,
    ),
  );
}
