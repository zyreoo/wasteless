import '../widgets/image_loading.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/live_page.dart';
import 'components.dart';
import 'preferences.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppPreferences.instance,
    builder: (context, _) {
      final prefs = AppPreferences.instance;
      return LiveScaffold(
        title: 'Setări',
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const PageIntro(
                  'Pe gustul tău',
                  'Mici detalii.\nO experiență mai bună.',
                  'Preferințele sunt păstrate pe acest dispozitiv.',
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: prefs.city,
                      decoration: const InputDecoration(
                        labelText: 'Orașul pentru explorare',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      items: [
                        for (final city in ['București', 'Cluj-Napoca'])
                          DropdownMenuItem(value: city, child: Text(city)),
                      ],
                      onChanged: (city) => prefs.update(city: city),
                    ),
                  ),
                ),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: prefs.reduceMotion,
                        onChanged: (value) => prefs.update(reduceMotion: value),
                        title: const Text('Animații reduse'),
                        subtitle: const Text(
                          'O experiență mai liniștită, cu mai puțină mișcare.',
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: prefs.showDemo,
                        onChanged: (value) => prefs.update(showDemo: value),
                        title: const Text('Comercianți demonstrativi'),
                        subtitle: const Text(
                          'Arată exemplele de comercianți pe hartă și în listă.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const ListTile(
                  leading: Icon(Icons.language),
                  title: Text('Limba aplicației'),
                  trailing: Text('Română'),
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Ajutor & întrebări'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/help'),
                ),
                ListTile(
                  leading: const Icon(Icons.eco_outlined),
                  title: const Text('Despre Wasteless'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/about'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) => LiveScaffold(
    title: 'Suntem aici să te ajutăm',
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const PageIntro(
              'Mai simplu decât crezi',
              'Întrebări mici.\nRăspunsuri clare.',
              'Tot ce trebuie să știi înainte să salvezi ceva bun.',
            ),
            const SizedBox(height: 28),
            for (final item in const [
              (
                'Cum cumpăr un produs?',
                'Deschide catalogul, alege un produs disponibil, selectează cantitatea și adaugă-l în coș. Verifică totalul înainte să confirmi comanda.',
              ),
              (
                'Ce înseamnă un pachet surpriză?',
                'O selecție de produse rămase la final de zi. Conținutul poate varia. Pachetele comercianților din demonstrație nu sunt disponibile pentru cumpărare.',
              ),
              (
                'Pot comanda de pe hartă?',
                'Harta afișează momentan comercianți demonstrativi, marcați DEMO. Pentru comenzile reale folosește catalogul.',
              ),
              (
                'Unde văd comenzile mele?',
                'În secțiunea Comenzi găsești istoricul și detaliile fiecărei comenzi.',
              ),
              (
                'Ce fac dacă am alergii?',
                'Verifică descrierea produsului și cere informații despre ingrediente și alergeni înainte de cumpărare. Nu presupune că un pachet este potrivit unei anumite diete.',
              ),
              (
                'Cum îmi recuperez parola?',
                'Pe ecranul de autentificare selectează „Ai uitat parola?” și introdu adresa de email a contului.',
              ),
            ])
              Card(
                child: ExpansionTile(
                  title: Text(
                    item.$1,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    Text(item.$2, style: const TextStyle(height: 1.7)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) => LiveScaffold(
    title: 'Despre Wasteless',
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageIntro(
                  'O idee bună, în fiecare zi',
                  'Mâncarea merită\no a doua șansă.',
                  'Wasteless conectează oamenii cu produsele care merită savurate, înainte să fie risipite.',
                ),
                const SizedBox(height: 28),
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: AspectRatio(
                    aspectRatio: 1.8,
                    child: Image.asset(
                      'assets/demo/rescue-bag.webp',
                      fit: BoxFit.cover,
                      frameBuilder: softImageFrame,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                for (final step in const [
                  (
                    '01',
                    'Descoperă',
                    'Explorează produse și locuri din orașul tău.',
                  ),
                  (
                    '02',
                    'Alege',
                    'Verifică descrierea, disponibilitatea și prețul.',
                  ),
                  (
                    '03',
                    'Bucură-te',
                    'Un gest mic pentru tine. Mai puțină risipă pentru toți.',
                  ),
                ])
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: lime,
                      child: Text(step.$1),
                    ),
                    title: Text(
                      step.$2,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(step.$3),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/home'),
                  child: const Text('Descoperă produsele'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class BusinessPage extends StatefulWidget {
  const BusinessPage({super.key});
  @override
  State<BusinessPage> createState() => _BusinessPageState();
}

class _BusinessPageState extends State<BusinessPage> {
  final name = TextEditingController(),
      city = TextEditingController(),
      description = TextEditingController();
  bool busy = false, loaded = false;
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    name.text = prefs.getString('partner.name') ?? '';
    city.text = prefs.getString('partner.city') ?? '';
    description.text = prefs.getString('partner.description') ?? '';
    setState(() => loaded = true);
  }

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('partner.name', name.text.trim());
      await prefs.setString('partner.city', city.text.trim());
      await prefs.setString('partner.description', description.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ciorna a fost salvată pe acest dispozitiv. Nu a fost trimisă.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LiveScaffold(
    title: 'Pentru comercianți',
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const PageIntro(
              'Bun pentru business. Bun pentru planetă.',
              'Dă valoare\nla ce rămâne.',
              'Pregătește profilul afacerii tale și transformă surplusul într-o oportunitate.',
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in const [
                  (Icons.storefront_outlined, 'Clienți noi'),
                  (Icons.eco_outlined, 'Mai puțină risipă'),
                  (Icons.shopping_bag_outlined, 'Produse valorificate'),
                ])
                  Chip(avatar: Icon(item.$1, size: 18), label: Text(item.$2)),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Profil de comerciant · ciornă',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Înscrierile comercianților nu sunt încă deschise. Poți pregăti o ciornă locală; aceasta nu publică oferte și nu trimite date.',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        enabled: loaded && !busy,
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Numele afacerii',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Completează numele afacerii.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        enabled: loaded && !busy,
                        controller: city,
                        decoration: const InputDecoration(labelText: 'Oraș'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Completează orașul.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        enabled: loaded && !busy,
                        controller: description,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Ce produse ai vrea să salvezi?',
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: loaded && !busy ? save : null,
                        child: Text(
                          busy ? 'Se salvează…' : 'Salvează ciorna local',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
