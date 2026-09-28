import 'package:flutter/material.dart';

import '../widgets/figma_layout.dart';
import 'design_page.dart';

/// Frame 10:4007: metadata geometry and Figma Desktop visual reference.
class OrderConfirmPage extends StatelessWidget {
  const OrderConfirmPage({super.key});
  static const green = Color(0xff40916c),
      dark = Color(0xff31572c),
      lime = Color(0xffecf39e);
  Widget label(
    String text, {
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = dark,
    TextAlign align = TextAlign.left,
  }) => Text(
    text,
    textAlign: align,
    style: TextStyle(
      fontFamilyFallback: const ['Apple Color Emoji', 'Noto Color Emoji'],
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.25,
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfffaf9f6),
    body: DesignViewport(
      height: 913,
      child: Stack(
        children: [
          Positioned(
            left: -5,
            top: -80,
            width: 400,
            height: 400,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: green.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(60),
              ),
            ),
          ),
          Positioned(
            left: 55,
            top: 60,
            width: 280,
            height: 280,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: lime.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(60),
              ),
            ),
          ),
          Positioned(
            left: 135,
            top: 90,
            width: 120,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                color: green,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: green.withValues(alpha: .2),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, size: 60, color: lime),
            ),
          ),
          Positioned(
            left: 32,
            top: 234,
            width: 334,
            child: label(
              'Comandă confirmată! 🎉',
              size: 27,
              weight: FontWeight.w800,
              align: TextAlign.center,
            ),
          ),
          Positioned(
            left: 32,
            top: 282,
            width: 334,
            child: label(
              'Mulțumim că ai salvat mâncare! Comanda ta\neste pregătită la magazin.',
              color: const Color(0xff6b6a63),
              align: TextAlign.center,
            ),
          ),
          Positioned(
            left: 20,
            top: 363.5,
            width: 350,
            height: 257.5,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      label('Comanda #1043', size: 13, weight: FontWeight.w700),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: green.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: label('De ridicat', size: 11, color: green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: label(['🥗', '🍞', '🥛'][i], size: 20),
                          ),
                          Expanded(
                            child: label(
                              [
                                'Bol de salată proaspătă',
                                'Pâine sourdough ×${PreviewState.instance.quantities[1]}',
                                'Iaurt grecesc 500g',
                              ][i],
                              size: 13,
                            ),
                          ),
                          label(
                            PreviewState.money(
                              PreviewState.instance.quantities[i] *
                                  [3.4, 2.8, 1.2][i],
                            ),
                            size: 13,
                            weight: FontWeight.w700,
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 18, color: Color(0xffeeeee9)),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Color(0xff9b9a94),
                      ),
                      const SizedBox(width: 10),
                      label(
                        'Piața Verde, Str. Eroilor 14',
                        size: 12,
                        color: const Color(0xff6b6a63),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 16,
                        color: Color(0xff9b9a94),
                      ),
                      const SizedBox(width: 10),
                      label(
                        'Ridică până la 20:00 azi',
                        size: 12,
                        color: const Color(0xff6b6a63),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 637,
            width: 350,
            height: 98,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(colors: [dark, green]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label(
                    '🌱 Impactul acestei comenzi',
                    size: 12,
                    weight: FontWeight.w700,
                    color: lime,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (final pair in [
                        ['1,8 kg', 'CO₂ salvat'],
                        ['9,90 lei', 'economisiți'],
                        ['${PreviewState.instance.count} produse', 'salvate'],
                      ])
                        Column(
                          children: [
                            label(
                              pair[0],
                              size: 19,
                              weight: FontWeight.w700,
                              color: lime,
                            ),
                            label(
                              pair[1],
                              size: 10,
                              color: const Color(0xffb6d1b9),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 755,
            width: 350,
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (_) => false,
              ),
              child: const Text(
                'Înapoi la pagina principală',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 823,
            width: 350,
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xffe0dfd9)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => Navigator.pushNamed(context, '/history'),
              child: const Text('Vezi comenzile mele'),
            ),
          ),
        ],
      ),
    ),
  );
}
