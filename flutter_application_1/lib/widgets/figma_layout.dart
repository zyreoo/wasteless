import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

typedef DesignNode = Map<String, dynamic>;
typedef NodeOverride = Widget? Function(DesignNode node);

/// Local, versioned design data. All geometry is expressed in Flutter logical
/// pixels; the original Figma node IDs remain available for visual review.
class FigmaDesign {
  static Map<String, dynamic>? _screens;
  static Future<void> load() async {
    _screens ??= jsonDecode(
      await rootBundle.loadString('assets/figma/screens.json'),
    ) as Map<String, dynamic>;
  }

  static DesignNode screen(String id) =>
      Map<String, dynamic>.from(_screens![id] as Map);

  static String text(DesignNode n) =>
      (n['runs'] as List? ?? []).map((r) => r['text'] as String? ?? '').join();

  static List<DesignNode> children(DesignNode n) =>
      (n['children'] as List? ?? [])
          .map((c) => Map<String, dynamic>.from(c as Map))
          .toList();

  static double number(DesignNode n, String key, [double fallback = 0]) =>
      (n[key] as num?)?.toDouble() ?? fallback;
}

/// A mobile canvas that retains the source's spacing at 390 px and scales
/// uniformly on other phone widths. Large windows show a centered phone canvas.
/// Long content scrolls inside the designated panels, beneath fixed navigation.
class DesignViewport extends StatelessWidget {
  const DesignViewport({super.key, required this.child, this.height = 844});
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = math.min(box.maxWidth, 430.0);
      final scale = width / 390;
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: SizedBox(
              width: width,
              height: height * scale,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 390,
                maxWidth: 390,
                minHeight: height,
                maxHeight: height,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: SizedBox(width: 390, height: height, child: child),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class FigmaLayout extends StatelessWidget {
  const FigmaLayout({
    super.key,
    required this.node,
    this.actions = const {},
    this.nodeBuilder,
    this.verticalScroll = const {},
    this.horizontalScroll = const {},
    this.hidden = const {},
    this.textValues = const {},
    this.patches = const {},
  });
  final DesignNode node;
  final Map<String, VoidCallback> actions;
  final NodeOverride? nodeBuilder;
  final Set<String> verticalScroll, horizontalScroll, hidden;
  final Map<String, String> textValues;
  final Map<String, DesignNode> patches;

  @override
  Widget build(BuildContext context) => _render(
    context,
    node,
    390,
    844,
    const TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 14,
      color: Color(0xff31572c),
      fontWeight: FontWeight.w400,
      decoration: TextDecoration.none,
    ),
  );

  TextStyle _style(DesignNode n, TextStyle parent) {
    final fs = FigmaDesign.number(n, 'fontSize', parent.fontSize ?? 14);
    final weight = (n['weight'] as int?);
    return parent.copyWith(
      fontFamily: 'PlusJakartaSans',
      fontSize: fs,
      fontFamilyFallback: const ['Apple Color Emoji', 'Noto Color Emoji'],
      color: n['color'] == null ? null : Color(n['color'] as int),
      fontWeight: weight == null
          ? null
          : FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
      height: n['lineHeight'] == null
          ? (n['heightFactor'] as num?)?.toDouble()
          : FigmaDesign.number(n, 'lineHeight') / fs,
      letterSpacing: (n['letterSpacing'] as num?)?.toDouble(),
      decoration: n['strike'] == true
          ? TextDecoration.lineThrough
          : parent.decoration,
    );
  }

  double _dimension(DesignNode n, String dimension, double parent) =>
      n['${dimension}Percent'] != null
      ? parent * FigmaDesign.number(n, '${dimension}Percent') / 100
      : FigmaDesign.number(n, dimension, parent);

  Widget _render(
    BuildContext context,
    DesignNode original,
    double pw,
    double ph,
    TextStyle inherited,
  ) {
    final id = original['id'] as String? ?? '';
    if (hidden.contains(id)) return const SizedBox.shrink();
    final n = _resolve({...original, ...?patches[id]}, pw, ph);
    final w = _dimension(n, 'width', pw), h = _dimension(n, 'height', ph);
    final style = _style(n, inherited);
    final radius = BorderRadius.only(
      topLeft: Radius.circular(
        FigmaDesign.number(n, 'topRadius', FigmaDesign.number(n, 'radius')),
      ),
      topRight: Radius.circular(
        FigmaDesign.number(n, 'topRadius', FigmaDesign.number(n, 'radius')),
      ),
      bottomLeft: Radius.circular(
        FigmaDesign.number(
          n,
          'bottomLeftRadius',
          FigmaDesign.number(
            n,
            'bottomRadius',
            FigmaDesign.number(n, 'radius'),
          ),
        ),
      ),
      bottomRight: Radius.circular(
        FigmaDesign.number(
          n,
          'bottomRightRadius',
          FigmaDesign.number(
            n,
            'bottomRadius',
            FigmaDesign.number(n, 'radius'),
          ),
        ),
      ),
    );
    Widget content;
    final custom = nodeBuilder?.call(n);
    if (custom != null) {
      content = custom;
    } else if (n.containsKey('runs')) {
      final runs = (n['runs'] as List).cast<Map<String, dynamic>>();
      final align = n['align'] == 'center'
          ? TextAlign.center
          : n['align'] == 'right'
          ? TextAlign.right
          : TextAlign.left;
      content = RichText(
        text: TextSpan(
          style: style,
          children: textValues.containsKey(id)
              ? [TextSpan(text: textValues[id])]
              : runs
                    .map(
                      (r) => TextSpan(
                        text: r['text'] as String?,
                        style: _style(r, style),
                      ),
                    )
                    .toList(),
        ),
        textAlign: align,
        textScaler: MediaQuery.textScalerOf(context),
        overflow: TextOverflow.visible,
        textHeightBehavior: const TextHeightBehavior(
          leadingDistribution: TextLeadingDistribution.even,
        ),
      );
      if (n['centerY'] == true) content = Center(child: content);
    } else {
      final children = FigmaDesign.children(n);
      var canvasW = w, canvasH = h;
      final vertical = verticalScroll.contains(id),
          horizontal = horizontalScroll.contains(id);
      for (final c in children) {
        if (vertical) {
          canvasH = math.max(
            canvasH,
            FigmaDesign.number(c, 'y') + FigmaDesign.number(c, 'height') + 20,
          );
        }
        if (horizontal) {
          canvasW = math.max(
            canvasW,
            FigmaDesign.number(c, 'x') + FigmaDesign.number(c, 'width') + 24,
          );
        }
      }
      content = SizedBox(
        width: canvasW,
        height: canvasH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (n['asset'] != null)
              Positioned.fill(child: DesignAsset(n['asset'] as String)),
            for (final c0 in children)
              if (!hidden.contains(c0['id']))
                _position(
                  context,
                  {...c0, ...?patches[c0['id']]},
                  w,
                  h,
                  style,
                  n,
                ),
          ],
        ),
      );
      if (vertical || horizontal) {
        content = SingleChildScrollView(
          key: PageStorageKey('scroll-$id'),
          scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
          child: content,
        );
      }
    }
    final bw = FigmaDesign.number(n, 'borderWidth');
    final side = BorderSide(
      color: Color(n['borderColor'] as int? ?? 0xffe0dfd9),
      width: bw,
    );
    Border? border;
    if (bw > 0) {
      border = switch (n['borderSide']) {
        'l' => Border(left: side),
        'r' => Border(right: side),
        't' => Border(top: side),
        'b' => Border(bottom: side),
        _ => Border.fromBorderSide(side),
      };
    }
    final colors = (n['gradient'] as List?)?.cast<int>();
    final angle = FigmaDesign.number(n, 'gradientAngle', 135) * math.pi / 180;
    final shadow = n['shadow'] as List?;
    if (n['clip'] == true) {
      content = ClipRRect(borderRadius: radius, child: content);
    }
    content = DecoratedBox(
      decoration: BoxDecoration(
        color: n['background'] == null ? null : Color(n['background'] as int),
        borderRadius: radius,
        gradient: colors == null
            ? null
            : LinearGradient(
                begin: Alignment(-math.sin(angle), math.cos(angle)),
                end: Alignment(math.sin(angle), -math.cos(angle)),
                colors: colors.map(Color.new).toList(),
              ),
        boxShadow: shadow == null
            ? null
            : [
                BoxShadow(
                  offset: Offset(
                    (shadow[0] as num).toDouble(),
                    (shadow[1] as num).toDouble(),
                  ),
                  blurRadius: (shadow[2] as num).toDouble() * 2,
                  color: Color(shadow[3] as int),
                ),
              ],
      ),
      child: content,
    );
    if (border != null) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: border,
          borderRadius: n['borderSide'] == null ? radius : null,
        ),
        child: content,
      );
    }
    if (n['opacity'] != null) {
      content = Opacity(
        opacity: FigmaDesign.number(n, 'opacity', 1),
        child: content,
      );
    }
    if (actions.containsKey(id)) {
      content = Semantics(
        button: true,
        label: _label(n),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: ValueKey('action-$id'),
            behavior: HitTestBehavior.opaque,
            onTap: actions[id],
            child: content,
          ),
        ),
      );
    }
    return SizedBox(
      key: ValueKey('node-$id'),
      width: w,
      height: h,
      child: content,
    );
  }

  String _label(DesignNode n) {
    final own = FigmaDesign.text(n);
    return own.isNotEmpty
        ? own
        : FigmaDesign.children(n)
              .map(_label)
              .where((s) => s.isNotEmpty)
              .join(' ');
  }

  DesignNode _resolve(DesignNode node, double pw, double ph) {
    if (node['insets'] == null) return node;
    final values = (node['insets'] as List).cast<String>();
    double value(String s, double parent) => s.endsWith('%')
        ? double.parse(s.substring(0, s.length - 1)) * parent / 100
        : double.parse(s.replaceAll('px', ''));
    final top = value(values[0], ph), right = value(values[1], pw);
    final bottom = value(values[2], ph), left = value(values[3], pw);
    return {
      ...node,
      'x': left,
      'y': top,
      'width': math.max(0.0, pw - left - right),
      'height': math.max(0.0, ph - top - bottom),
    };
  }

  Widget _position(
    BuildContext context,
    DesignNode c,
    double pw,
    double ph,
    TextStyle style,
    DesignNode parent,
  ) {
    c = _resolve(c, pw, ph);
    final w = _dimension(c, 'width', pw), h = _dimension(c, 'height', ph);
    var x = FigmaDesign.number(c, 'x'), y = FigmaDesign.number(c, 'y');
    if (c['xPercent'] != null) x = pw * FigmaDesign.number(c, 'xPercent') / 100;
    if (c['yPercent'] != null) y = ph * FigmaDesign.number(c, 'yPercent') / 100;
    if (c['rightPercent'] != null) {
      x = pw - pw * FigmaDesign.number(c, 'rightPercent') / 100 - w;
    }
    if (c['bottomPercent'] != null) {
      y = ph - ph * FigmaDesign.number(c, 'bottomPercent') / 100 - h;
    }
    x += w * FigmaDesign.number(c, 'translateX');
    y += h * FigmaDesign.number(c, 'translateY');
    // CSS absolute children in Figma's reference are offset inside the border.
    if (parent['borderSide'] == null) {
      x += FigmaDesign.number(parent, 'borderWidth');
      y += FigmaDesign.number(parent, 'borderWidth');
    } else if (parent['borderSide'] == 'l') {
      x += FigmaDesign.number(parent, 'borderWidth');
    } else if (parent['borderSide'] == 't') {
      y += FigmaDesign.number(parent, 'borderWidth');
    }
    return Positioned(
      left: x,
      top: y,
      width: w,
      height: h,
      child: _render(context, c, pw, ph, style),
    );
  }
}

class DesignAsset extends StatelessWidget {
  const DesignAsset(this.path, {super.key});
  final String path;
  @override
  Widget build(BuildContext context) => path.endsWith('.svg')
      ? SvgPicture.asset(
          path,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.fill,
        )
      : Image.asset(
          path,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.fill,
        );
}
