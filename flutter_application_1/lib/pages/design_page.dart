import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/figma_layout.dart';
import '../auth/auth_controller.dart';

/// Screen catalogue mirrors the 18 artboards in the supplied Figma file.
const designRoutes = <String, String>{
  '/': '5:6',
  '/onboarding/food': '5:42',
  '/onboarding/nearby': '10:4166',
  '/onboarding/impact': '10:4212',
  '/login': '5:91',
  '/register': '5:181',
  '/home': '5:304',
  '/search': '5:564',
  '/notifications': '5:829',
  '/profile': '5:961',
  '/settings': '5:1181',
  '/location': '5:1353',
  '/history': '10:3515',
  '/store': '10:3617',
  '/product': '10:3721',
  '/cart': '10:3827',
  '/checkout': '10:3928',
};

/// UI preview state, deliberately independent of authentication/payment APIs.
/// Seed values reproduce the source artboards on first launch.
class PreviewState extends ChangeNotifier {
  static final instance = PreviewState();
  final quantities = <int>[1, 2, 1];
  final saved = <String>{};
  final settings = <String, bool>{
    '5:1244': true,
    '5:1249': true,
    '5:1252': false,
    '5:1267': false,
  };
  int get count => quantities.fold(0, (a, b) => a + b);
  double get subtotal =>
      quantities[0] * 3.4 + quantities[1] * 2.8 + quantities[2] * 1.2;
  double get total => subtotal + .5;
  void changeQuantity(int index, int delta) {
    quantities[index] = (quantities[index] + delta).clamp(1, 99);
    notifyListeners();
  }

  void toggleSaved(String id) {
    saved.contains(id) ? saved.remove(id) : saved.add(id);
    notifyListeners();
  }

  void toggleSetting(String id) {
    settings[id] = !(settings[id] ?? false);
    notifyListeners();
  }

  static String money(double value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} lei';
}

class DesignPage extends StatefulWidget {
  const DesignPage({
    super.key,
    required this.nodeId,
    this.savedOnly = false,
    this.auth,
  });
  final AuthController? auth;
  final String nodeId;
  final bool savedOnly;
  @override
  State<DesignPage> createState() => _DesignPageState();
}

class _DesignPageState extends State<DesignPage> {
  final state = PreviewState.instance;
  final controllers = <String, TextEditingController>{};
  final hidden = <String>{};
  final patches = <String, DesignNode>{};
  final values = <String, String>{};
  int quantity = 1, category = 0, historyFilter = 0, payment = 0;
  bool obscure = true, accepted = true, read = false, sorted = false;
  String query = '';
  bool submitting = false;

  Future<void> authenticate(bool register) async {
    if (submitting) return;
    final email = controllers[register ? '5:259' : '5:148']?.text.trim() ?? '';
    final password = controllers[register ? '5:270' : '5:156']?.text ?? '';
    if (!email.contains('@') || password.isEmpty || (register && !accepted)) {
      notice('Completează emailul, parola și acordul necesar.');
      return;
    }
    setState(() => submitting = true);
    try {
      if (register) {
        final active = await widget.auth!.register(
          email,
          password,
          controllers['5:253']?.text ?? '',
        );
        if (mounted && !active) {
          notice(
            'Verifică emailul pentru confirmarea contului, apoi autentifică-te.',
          );
        }
      } else {
        await widget.auth!.login(email, password);
      }
    } catch (error) {
      if (mounted) notice(AuthController.message(error));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    state.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    state.removeListener(refresh);
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void go(String route) => Navigator.pushNamed(context, route);
  void back() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void notice(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> information(String title, String text) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Închide'),
        ),
      ],
    ),
  );

  Map<String, VoidCallback> get actions {
    final a = <String, VoidCallback>{};
    void route(String id, String path) {
      a[id] = () => go(path);
    }

    for (final e in <String, String>{
      '5:30': '/onboarding/food',
      '5:31': '/login',
      '5:44': '/register',
      '5:80': '/onboarding/nearby',
      '10:4169': '/register',
      '10:4208': '/onboarding/impact',
      '10:4247': '/register',
      '10:4249': '/login',
      '5:115': '/register',
      '5:204': '/login',
      '5:110': '/home',
      '5:199': '/home',
      '5:401': '/notifications',
      '5:402': '/profile',
      '5:350': '/search',
      '5:418': '/location',
      '5:351': '/product',
      '5:352': '/product',
      '5:353': '/product',
      '5:409': '/search',
      '5:410': '/search',
      '5:411': '/search',
      '5:412': '/search',
      '5:359': '/store',
      '5:360': '/store',
      '5:1015': '/register',
      '5:1016': '/history',
      '5:1017': '/saved',
      '5:1019': '/settings',
      '5:990': '/settings',
      '5:1211': '/register',
      '5:1217': '/location',
      '5:1408': '/store',
      '5:1409': '/store',
      '5:1410': '/store',
      '10:3551': '/order-confirm',
      '10:3572': '/order-confirm',
      '10:3590': '/order-confirm',
      '10:3553': '/cart',
      '10:3748': '/store',
      '10:3924': '/checkout',
      '10:3958': '/store',
      '10:4001': '/order-confirm',
    }.entries) {
      route(e.key, e.value);
    }
    for (final ids in [
      ['5:319', '5:320', '5:321', '5:322', '5:323'],
      ['5:581', '5:582', '5:583', '5:584', '5:585'],
      ['5:982', '5:983', '5:984', '5:985', '5:986'],
    ]) {
      for (var i = 0; i < ids.length; i++) {
        route(
          ids[i],
          ['/home', '/search', '/location', '/saved', '/profile'][i],
        );
      }
    }
    for (final id in [
      '5:853',
      '5:1185',
      '10:3518',
      '10:3622',
      '10:3736',
      '10:3830',
      '10:3931',
    ]) {
      a[id] = back;
    }
    route('5:840', '/product');
    route('5:841', '/history');
    route('5:842', '/profile');
    route('5:846', '/product');
    route('5:847', '/store');
    for (var i = 0; i < 6; i++) {
      route('5:${613 + i}', '/product');
      a['5:${745 + i * 5}'] = () {
        notice('Produs adăugat în coș');
        go('/cart');
      };
    }
    for (final id in ['10:3661', '10:3676', '10:3691', '10:3706']) {
      route(id, '/product');
    }
    for (final id in ['10:3673', '10:3688', '10:3703', '10:3718']) {
      route(id, '/cart');
    }
    for (final id in ['5:141', '5:142', '5:245', '5:246']) {
      a[id] = () => information(
        'Autentificare',
        'Acesta este prototipul interfeței. Autentificarea externă nu este conectată.',
      );
    }
    a['5:109'] = () => information(
      'Recuperare parolă',
      'Introdu adresa de email în formular. Trimiterea mesajului de recuperare necesită conectarea serviciului de autentificare.',
    );
    a['5:157'] = () => setState(() => obscure = !obscure);
    a['5:233'] = () => setState(() => accepted = !accepted);
    a['5:199'] = () {
      if (accepted) {
        go('/home');
      } else {
        notice('Bifează acordul pentru a continua în prototip.');
      }
    };
    a['5:1020'] = () =>
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    a['5:1018'] = () => go('/onboarding/impact');
    a['5:836'] = () => setState(() => read = true);
    for (final id in state.settings.keys) {
      a[id] = () => state.toggleSetting(id);
    }
    for (final id in [
      '5:1212',
      '5:1213',
      '5:1218',
      '5:1220',
      '5:1221',
      '5:1207',
    ]) {
      a[id] = () => information(
        'Previzualizare interfață',
        'Această opțiune necesită conectarea serviciului aplicației. Nicio modificare de cont nu a fost trimisă.',
      );
    }
    a['10:3779'] = () => setState(() => quantity = math.max(1, quantity - 1));
    a['10:3783'] = () => setState(() => quantity = math.min(3, quantity + 1));
    a['10:3821'] = () {
      state.changeQuantity(0, quantity);
      go('/cart');
    };
    for (var i = 0; i < 3; i++) {
      a[['10:3848', '10:3871', '10:3890'][i]] = () =>
          state.changeQuantity(i, -1);
      a[['10:3852', '10:3875', '10:3894'][i]] = () =>
          state.changeQuantity(i, 1);
    }
    for (final id in ['10:3739', '10:3625', '5:676']) {
      a[id] = () => state.toggleSaved(id);
    }
    for (var i = 0; i < 5; i++) {
      a['5:${574 + i}'] = () => setState(() => category = i);
    }
    for (var i = 0; i < 4; i++) {
      a['10:${3523 + i * 2}'] = () => setState(() => historyFilter = i);
    }
    a['5:612'] = () => setState(() => sorted = !sorted);
    a['5:593'] = () => showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Filtrează ofertele',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            for (var i = 0; i < 5; i++)
              ListTile(
                title: Text(
                  ['Toate', 'Legume', 'Brutărie', 'Lactate', 'Preparate'][i],
                ),
                onTap: () {
                  setState(() => category = i);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      a[['10:3968', '10:3979', '10:3984'][i]] = () =>
          setState(() => payment = i);
    }
    a['10:3989'] = () => information(
      'Cod promoțional',
      'Codurile promoționale vor fi validate după conectarea serviciului de comenzi.',
    );
    if (widget.auth != null) {
      a['5:110'] = () => authenticate(false);
      a['5:199'] = () => authenticate(true);
    }
    return a;
  }

  void prepare(DesignNode root) {
    hidden.clear();
    if (widget.auth != null) {
      hidden.addAll(['5:141', '5:142', '5:245', '5:246', '5:109']);
    }
    patches.clear();
    values.clear();
    // Source navigation is pinned at y=764; only the content above it scrolls.
    patches['5:308'] = {'height': 486.0};
    patches['5:148'] = {'width': 260.0};
    patches['5:156'] = {'width': 220.0};
    patches['5:568'] = {'height': 542.0};
    patches['5:965'] = {'height': 439.0};
    values['10:3782'] = '$quantity';
    for (var i = 0; i < 3; i++) {
      values[['10:3851', '10:3874', '10:3893'][i]] = '${state.quantities[i]}';
    }
    values['10:3834'] = '${state.count} produse';
    values['10:3905'] = '${state.count} produse';
    for (final id in ['10:3915', '10:3950']) {
      values[id] = PreviewState.money(state.subtotal);
    }
    for (final id in ['10:3922', '10:3956', '10:4000']) {
      values[id] = PreviewState.money(state.total);
    }
    values['10:3925'] = 'Finalizează · ${PreviewState.money(state.total)}';
    for (var i = 0; i < 3; i++) {
      values[['10:3939', '10:3942', '10:3945'][i]] =
          '${['Bol de salată', 'Pâine sourdough', 'Iaurt grecesc'][i]} × ${state.quantities[i]}';
      values[['10:3940', '10:3943', '10:3946'][i]] = PreviewState.money(
        state.quantities[i] * [3.4, 2.8, 1.2][i],
      );
    }
    if (!accepted) hidden.add('5:275');
    if (payment != 0) hidden.add('10:3972');
    patches['10:3983'] = {'background': payment == 1 ? 0xff40916c : 0x00000000};
    patches['10:3988'] = {'background': payment == 2 ? 0xff40916c : 0x00000000};
    if (read) {
      hidden.addAll(['5:859', '5:862']);
      values['5:836'] = 'Toate citite';
    }
    for (final e in state.settings.entries) {
      patches[e.key] = {'background': e.value ? 0xff40916c : 0xffd1d0c9};
      final knob = {
        '5:1244': '5:1312',
        '5:1249': '5:1316',
        '5:1252': '5:1325',
        '5:1267': '5:1348',
      }[e.key]!;
      patches[knob] = {'x': e.value ? 21.0 : 3.0};
    }
    for (final id in state.saved) {
      patches[id] = {'background': 0xff90a955, 'radius': 8.0};
    }
    if (widget.nodeId == '5:564') {
      final categories = [1, 2, 1, 4, 3, 3];
      final names = [
        'Spanac proaspăt Piața Verde',
        'Croissant cu unt Brutăria Artizanală',
        'Mere Ionatan Piața Verde',
        'Platou sushi mixt Sakura Resto',
        'Lapte bio Metro Fresh',
        'Brânză telemea Metro Fresh',
      ];
      var visible = List.generate(6, (i) => i)
          .where(
            (i) =>
                (category == 0 || categories[i] == category) &&
                names[i].toLowerCase().contains(query.toLowerCase()) &&
                (!widget.savedOnly || state.saved.isNotEmpty && i == 0),
          )
          .toList();
      if (sorted) {
        visible.sort(
          (a, b) => [
            1.2,
            2.0,
            3.25,
            22.0,
            4.2,
            8.4,
          ][a].compareTo([1.2, 2.0, 3.25, 22.0, 4.2, 8.4][b]),
        );
      }
      for (var i = 0; i < 6; i++) {
        final index = visible.indexOf(i);
        if (index < 0) {
          hidden.add('5:${613 + i}');
        } else {
          patches['5:${613 + i}'] = {
            'x': (index % 2) * 178.0,
            'y': (index ~/ 2) * 227.0,
          };
        }
      }
      if (category != 0 || query.isNotEmpty || widget.savedOnly) {
        values['5:611'] = '${visible.length} oferte găsite';
      }
      if (widget.savedOnly) values['5:572'] = 'Produse salvate';
      if (sorted) values['5:659'] = 'Preț ↑';
      for (var i = 0; i < 5; i++) {
        patches['5:${574 + i}'] = {
          'background': category == i ? 0xff31572c : 0xffffffff,
        };
        patches['5:${596 + i * 3}'] = {
          'color': category == i ? 0xffecf39e : 0xff6b6a63,
        };
      }
    }
    if (historyFilter != 0) {
      final cards = ['10:3533', '10:3558', '10:3575', '10:3592'];
      final keep = historyFilter == 1
          ? [0, 2]
          : historyFilter == 2
          ? [1]
          : [3];
      hidden.addAll(['10:3532', '10:3574', '10:3603']);
      var y = 12.0;
      for (var i = 0; i < cards.length; i++) {
        if (!keep.contains(i)) {
          hidden.add(cards[i]);
        } else {
          patches[cards[i]] = {'y': y};
          y += i == 0 ? 234 : 180;
        }
      }
    }
    for (var i = 0; i < 4; i++) {
      patches['10:${3523 + i * 2}'] = {
        'background': historyFilter == i ? 0xff31572c : 0xffffffff,
      };
      patches['10:${3524 + i * 2}'] = {
        'color': historyFilter == i ? 0xfffaf9f6 : 0xff6b6a63,
      };
    }
  }

  Widget? field(DesignNode n) {
    final id = n['id'] as String?;
    const editable = [
      '5:148',
      '5:156',
      '5:253',
      '5:259',
      '5:263',
      '5:270',
      '5:592',
    ];
    if (!editable.contains(id)) return null;
    final password = id == '5:156' || id == '5:270';
    final search = id == '5:592';
    final controller = controllers.putIfAbsent(
      id!,
      () => TextEditingController(),
    );
    return TextField(
      key: ValueKey('field-$id'),
      controller: controller,
      obscureText: password && obscure,
      keyboardType: id == '5:263'
          ? TextInputType.phone
          : ['5:148', '5:259'].contains(id)
          ? TextInputType.emailAddress
          : TextInputType.text,
      textInputAction: search ? TextInputAction.search : TextInputAction.next,
      style: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: FigmaDesign.number(n, 'fontSize', 15),
        height: 1.25,
        color: const Color(0xff31572c),
      ),
      decoration: InputDecoration(
        hintText: FigmaDesign.text(n),
        hintStyle: TextStyle(color: Color(n['color'] as int? ?? 0xffb8b7b1)),
        isCollapsed: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: search ? (v) => setState(() => query = v) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final root = FigmaDesign.screen(widget.nodeId);
    prepare(root);
    return Scaffold(
      backgroundColor: const Color(0xfffaf9f6),
      body: AbsorbPointer(
        absorbing: submitting,
        child: Stack(
          children: [
            DesignViewport(
              child: FigmaLayout(
                node: root,
                actions: actions,
                nodeBuilder: field,
                hidden: hidden,
                patches: patches,
                textValues: values,
                verticalScroll: const {
                  '5:185',
                  '5:95',
                  '5:308',
                  '5:568',
                  '5:832',
                  '5:965',
                  '5:1184',
                  '5:1358',
                  '10:3531',
                  '10:3646',
                  '10:3747',
                  '10:3835',
                  '10:3935',
                },
                horizontalScroll: const {
                  '5:316',
                  '5:567',
                  '5:1357',
                  '5:1014',
                  '10:3522',
                  '10:3650',
                  '10:3787',
                },
              ),
            ),
            if (submitting)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66ffffff),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
