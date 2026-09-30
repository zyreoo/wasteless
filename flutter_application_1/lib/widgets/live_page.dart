import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';

class LoadPanel<T> extends StatefulWidget {
  const LoadPanel({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(T value, Future<void> Function() reload) builder;
  @override
  State<LoadPanel<T>> createState() => _LoadPanelState<T>();
}

class _LoadPanelState<T> extends State<LoadPanel<T>> {
  late Future<T> future = widget.load();
  Future<void> reload() async {
    if (!mounted) return;
    final next = widget.load();
    setState(() => future = next);
    try {
      await next;
    } catch (_) {
      /* FutureBuilder renders the error. */
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done &&
          !snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AuthController.message(snapshot.error!)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: reload,
                  child: const Text('Încearcă din nou'),
                ),
              ],
            ),
          ),
        );
      }
      return widget.builder(snapshot.data as T, reload);
    },
  );
}

class LiveScaffold extends StatelessWidget {
  const LiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.index,
  });
  final String title;
  final Widget body;
  final int? index;
  static const routes = ['/home', '/search', '/saved', '/cart', '/history'];
  static const destinations = [
    NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Acasă'),
    NavigationDestination(
      icon: Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map),
      label: 'Explorează',
    ),
    NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Salvate'),
    NavigationDestination(
      icon: Icon(Icons.shopping_bag_outlined),
      label: 'Coș',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      label: 'Comenzi',
    ),
  ];

  void select(BuildContext context, int destination) {
    if (destination != index) {
      Navigator.pushReplacementNamed(context, routes[destination]);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900 && index != null;
      final animation = ModalRoute.of(context)?.animation;
      final content = SafeArea(
        child:
            index != null &&
                animation != null &&
                !MediaQuery.disableAnimationsOf(context)
            ? FadeTransition(opacity: animation, child: body)
            : body,
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
          actions: [
            IconButton(
              tooltip: 'Setări',
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              icon: const Icon(Icons.tune),
            ),
            IconButton(
              tooltip: 'Contul meu',
              onPressed: () => Navigator.pushNamed(context, '/profile'),
              icon: const Icon(Icons.person_outline),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: wide
            ? Row(
                children: [
                  NavigationRail(
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Icon(Icons.eco, size: 32),
                    ),
                    backgroundColor: const Color(0xfff0f3e9),
                    selectedIndex: index!,
                    onDestinationSelected: (i) => select(context, i),
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final item in destinations)
                        NavigationRailDestination(
                          icon: item.icon,
                          label: Text(item.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              )
            : content,
        bottomNavigationBar: index == null || wide
            ? null
            : NavigationBar(
                selectedIndex: index!,
                onDestinationSelected: (i) => select(context, i),
                destinations: destinations,
              ),
      );
    },
  );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_basket_outlined, size: 64),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            child: const Text('Vezi produsele'),
          ),
        ],
      ),
    ),
  );
}
