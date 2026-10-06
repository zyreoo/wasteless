import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

export 'ui.dart';

class LoadPanel<T> extends StatefulWidget {
  const LoadPanel({
    super.key,
    required this.load,
    required this.builder,
    this.loading,
    this.errorTitle = 'Nu am putut încărca pagina',
  });
  final Future<T> Function() load;
  final Widget Function(T value, Future<void> Function() reload) builder;

  /// Shown on first load instead of a bare spinner, e.g. a skeleton layout.
  final Widget? loading;
  final String errorTitle;
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
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
      }
      if (snapshot.hasError) {
        return StatusPanel(
          icon: Icons.wifi_off_rounded,
          title: widget.errorTitle,
          detail: AuthController.message(snapshot.error!),
          action: FilledButton.icon(
            onPressed: reload,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Încearcă din nou'),
          ),
        );
      }
      return widget.builder(snapshot.data as T, reload);
    },
  );
}

/// App shell: a sidebar on desktop, four bottom tabs on phones. The map is
/// part of discovery, so on phones it highlights the Descoperă tab.
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
  static const _items = <(IconData, IconData, String)>[
    (Icons.local_offer_outlined, Icons.local_offer, 'Descoperă'),
    (Icons.map_outlined, Icons.map, 'Hartă'),
    (Icons.favorite_border, Icons.favorite, 'Favorite'),
    (Icons.shopping_bag_outlined, Icons.shopping_bag, 'Coș'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Comenzi'),
  ];
  static const _phoneTabs = [0, 2, 3, 4];

  void select(BuildContext context, int destination) {
    if (destination != index) {
      Navigator.pushReplacementNamed(context, routes[destination]);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= Breakpoints.sidebar;
      final animation = ModalRoute.of(context)?.animation;
      final content = SafeArea(
        top: false,
        child:
            index != null &&
                animation != null &&
                !MediaQuery.disableAnimationsOf(context)
            ? FadeTransition(opacity: animation, child: body)
            : body,
      );
      final bar = AppBar(
        automaticallyImplyLeading: index == null,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(),
        ),
        actions: wide
            ? null
            : [
                IconButton(
                  tooltip: 'Contul meu',
                  onPressed: () => Navigator.pushNamed(context, '/profile'),
                  icon: const Icon(Icons.account_circle_outlined),
                ),
                const SizedBox(width: Space.xs),
              ],
      );
      if (wide) {
        return Scaffold(
          body: Row(
            children: [
              _Sidebar(selected: index, onSelect: (i) => select(context, i)),
              const VerticalDivider(width: 1),
              Expanded(
                child: Scaffold(appBar: bar, body: content),
              ),
            ],
          ),
        );
      }
      final tab = index == null
          ? null
          : _phoneTabs.contains(index)
          ? _phoneTabs.indexOf(index!)
          : 0;
      return Scaffold(
        appBar: bar,
        body: content,
        bottomNavigationBar: tab == null
            ? null
            : DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: NavigationBar(
                  selectedIndex: tab,
                  onDestinationSelected: (i) => select(context, _phoneTabs[i]),
                  destinations: [
                    for (final i in _phoneTabs)
                      NavigationDestination(
                        icon: Icon(_items[i].$1),
                        selectedIcon: Icon(_items[i].$2),
                        label: _items[i].$3,
                      ),
                  ],
                ),
              ),
      );
    },
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelect});
  final int? selected;
  final void Function(int) onSelect;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    child: SizedBox(
      width: 248,
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.m,
            Space.l,
            Space.m,
            Space.l,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, 0, 0),
                child: Semantics(
                  header: true,
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Wordmark(),
                  ),
                ),
              ),
              const SizedBox(height: Space.xxl),
              for (var i = 0; i < LiveScaffold._items.length; i++)
                _NavItem(
                  icon: selected == i
                      ? LiveScaffold._items[i].$2
                      : LiveScaffold._items[i].$1,
                  label: LiveScaffold._items[i].$3,
                  selected: selected == i,
                  onTap: () => onSelect(i),
                ),
              const Spacer(),
              const Divider(),
              const SizedBox(height: Space.s),
              _NavItem(
                icon: Icons.storefront_outlined,
                label: 'Pentru comercianți',
                selected: false,
                onTap: () => Navigator.pushNamed(context, '/business'),
              ),
              _NavItem(
                icon: Icons.account_circle_outlined,
                label: 'Contul meu',
                selected: false,
                onTap: () => Navigator.pushNamed(context, '/profile'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.brandSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.s),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.s),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.m,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? AppColors.brand : AppColors.textSecondary,
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? AppColors.brand : AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Centred icon, title, explanation and action: used for empty and error
/// states so every screen reads the same way.
class StatusPanel extends StatelessWidget {
  const StatusPanel({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? detail;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(Radii.l),
                ),
                child: Icon(icon, size: 26, color: AppColors.textSecondary),
              ),
              const SizedBox(height: Space.l),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              if (detail != null) ...[
                const SizedBox(height: Space.s),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: Space.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel(
    this.message, {
    super.key,
    this.detail,
    this.icon = Icons.shopping_basket_outlined,
    this.actionLabel = 'Descoperă ofertele',
  });
  final String message;
  final String? detail;
  final IconData icon;
  final String actionLabel;
  @override
  Widget build(BuildContext context) => StatusPanel(
    icon: icon,
    title: message,
    detail: detail,
    action: FilledButton(
      onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
      child: Text(actionLabel),
    ),
  );
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

/// Icon + text row for pickup, address and similar facts.
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
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Text(
              text,
              style: emphasis
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.bodyMedium,
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
