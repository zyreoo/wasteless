import '../widgets/image_loading.dart';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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
                'O selecție de produse bune rămase la final de zi, la un preț redus. Conținutul variază de la o zi la alta.',
              ),
              (
                'Cum găsesc magazinele din apropiere?',
                'În secțiunea Magazine vezi lista și harta. Din catalog poți folosi locația ta pentru a ordona ofertele după distanță.',
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

class BusinessPage extends StatelessWidget {
  const BusinessPage({super.key});

  static const _benefits = [
    (
      Icons.savings_outlined,
      'Recuperezi din valoarea stocului',
      'Produsele bune rămase la final de zi se vând, în loc să fie aruncate.',
    ),
    (
      Icons.storefront_outlined,
      'Clienți noi din cartier',
      'Oamenii din apropiere îți descoperă magazinul și revin.',
    ),
    (
      Icons.schedule_outlined,
      'Câteva minute pe zi',
      'Publici un pachet surpriză, alegi intervalul de ridicare și gata.',
    ),
  ];

  static const _steps = [
    (
      'Creezi contul și profilul magazinului',
      'Nume, adresă, interval de ridicare și o fotografie.',
    ),
    (
      'Verificăm magazinul',
      'Magazinul devine vizibil pentru clienți după aprobare.',
    ),
    (
      'Publici pachete surpriză',
      'Stabilești prețul, valoarea estimată, stocul și ziua ridicării.',
    ),
    (
      'Predai comanda pe baza codului',
      'Clientul vine în intervalul ales și îți arată codul de ridicare.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LiveScaffold(
      title: 'Pentru comercianți',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const PageIntro(
                'Wasteless pentru afacerea ta',
                'Dă valoare la ce rămâne.',
                'Vinde pachete surpriză cu produsele nevândute ale zilei, către oameni din apropiere care vin să le ridice.',
              ),
              const SizedBox(height: Space.xl),
              Wrap(
                spacing: Space.m,
                runSpacing: Space.m,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: const Text('Înscrie-ți magazinul'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    child: const Text('Am deja cont'),
                  ),
                ],
              ),
              const SizedBox(height: Space.x3),
              for (final (icon, title, detail) in _benefits)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.l),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: AppColors.brand),
                      const SizedBox(width: Space.l),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: theme.textTheme.titleSmall),
                            const SizedBox(height: Space.xs),
                            Text(
                              detail,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Space.xl),
              const SectionTitle('Cum funcționează'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Space.l),
                  child: Column(
                    children: [
                      for (final (i, (title, detail)) in _steps.indexed)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i == _steps.length - 1 ? 0 : Space.l,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.brandSoft,
                                child: Text(
                                  '${i + 1}',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: AppColors.brand,
                                  ),
                                ),
                              ),
                              const SizedBox(width: Space.l),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: Space.xs),
                                    Text(
                                      detail,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.xl),
              Text(
                'Clienții plătesc la ridicare, direct în magazin. Ai întrebări? Scrie-ne din pagina de ajutor.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
