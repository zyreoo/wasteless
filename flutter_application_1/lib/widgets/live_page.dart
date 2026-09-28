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
      if (snapshot.connectionState != ConnectionState.done) {
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
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        IconButton(
          tooltip: 'Contul meu',
          onPressed: () => Navigator.pushNamed(context, '/profile'),
          icon: const Icon(Icons.person_outline),
        ),
      ],
    ),
    body: SafeArea(child: body),
    bottomNavigationBar: index == null
        ? null
        : NavigationBar(
            selectedIndex: index!,
            onDestinationSelected: (i) {
              if (i != index) {
                Navigator.pushReplacementNamed(
                  context,
                  ['/home', '/search', '/saved', '/cart', '/history'][i],
                );
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: 'Acasă',
              ),
              NavigationDestination(icon: Icon(Icons.search), label: 'Caută'),
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                label: 'Salvate',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                label: 'Coș',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                label: 'Comenzi',
              ),
            ],
          ),
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
