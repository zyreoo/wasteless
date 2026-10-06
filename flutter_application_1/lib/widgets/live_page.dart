import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';

class LoadPanel<T> extends StatefulWidget {
  const LoadPanel({
    super.key,
    required this.load,
    required this.builder,
    this.loading,
  });
  final Future<T> Function() load;
  final Widget Function(T value, Future<void> Function() reload) builder;

  /// Shown on first load instead of a bare spinner, e.g. a skeleton layout.
  final Widget? loading;
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
        return widget.loading ??
            const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AuthController.message(snapshot.error!),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Încearcă din nou'),
                  ),
                ],
              ),
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
          automaticallyImplyLeading: index == null,
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
  const EmptyPanel(
    this.message, {
    super.key,
    this.detail,
    this.icon = Icons.shopping_basket_outlined,
  });
  final String message;
  final String? detail;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: Color(0xffe8efdc),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(detail!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/home'),
                child: const Text('Vezi produsele'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps reading-width content (forms, carts, receipts) centred on wide
/// screens instead of stretching edge to edge.
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, this.maxWidth = 720, required this.child});
  final double maxWidth;
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Label/value row used in receipts and summaries.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.emphasis = false,
  });
  final IconData icon;
  final String text;
  final bool emphasis;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: emphasis
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Session-only browsing preferences; the scope is recreated on account changes.
class BrowseSession extends StatefulWidget {
  const BrowseSession({super.key, required this.child});
  final Widget child;
  @override
  State<BrowseSession> createState() => _BrowseSessionState();
}

class _BrowseSessionState extends State<BrowseSession> {
  final values = <String, Object?>{};
  final bucket = PageStorageBucket();
  @override
  Widget build(BuildContext context) =>
      BrowseMemory(values: values, bucket: bucket, child: widget.child);
}

class BrowseMemory extends InheritedWidget {
  const BrowseMemory({
    super.key,
    required this.values,
    required this.bucket,
    required super.child,
  });
  final Map<String, Object?> values;
  final PageStorageBucket bucket;
  static BrowseMemory? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BrowseMemory>();
  @override
  bool updateShouldNotify(BrowseMemory oldWidget) => false;
}
