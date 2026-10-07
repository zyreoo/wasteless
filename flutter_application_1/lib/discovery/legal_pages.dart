import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/live_page.dart';
import 'components.dart';

/// Shared layout for policy documents: intro, draft notice, numbered sections.
class LegalPage extends StatelessWidget {
  const LegalPage({
    super.key,
    required this.title,
    required this.summary,
    required this.sections,
  });
  final String title, summary;
  final List<(String, String)> sections;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LiveScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.all(Space.xl),
        children: [
          PageWidth(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageIntro('Wasteless', title, summary),
                const SizedBox(height: Space.l),
                DecoratedBox(
                  key: const ValueKey('legal-draft-notice'),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(Radii.m),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(Space.m),
                    child: InfoRow(
                      icon: Icons.gavel_outlined,
                      text: 'Versiune preliminară pentru perioada de testare. Documentul va fi completat cu datele operatorului și revizuit juridic înainte de lansarea publică.',
                    ),
                  ),
                ),
                const SizedBox(height: Space.xl),
                for (final (i, section) in sections.indexed) ...[
                  Text(
                    '${i + 1}. ${section.$1}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: Space.s),
                  Text(
                    section.$2,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: Space.xl),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});
  @override
  Widget build(BuildContext context) => const LegalPage(
    title: 'Termeni de utilizare',
    summary: 'Regulile simple după care funcționează Wasteless.',
    sections: [
      (
        'Ce este Wasteless',
        'Wasteless este o platformă prin care magazinele, brutăriile și restaurantele își oferă surplusul de mâncare de la finalul zilei, la preț redus, sub formă de pachete surpriză. Wasteless intermediază rezervarea; produsele sunt vândute de magazine.',
      ),
      (
        'Contul tău',
        'Pentru a rezerva ai nevoie de un cont cu o adresă de email validă. Ești responsabil pentru păstrarea parolei și pentru activitatea din contul tău.',
      ),
      (
        'Pachetele surpriză',
        'Conținutul unui pachet diferă de la o zi la alta și nu este cunoscut dinainte. Valoarea afișată este estimată de magazin și nu reprezintă o garanție a conținutului exact. Magazinul răspunde de calitatea, siguranța și etichetarea produselor.',
      ),
      (
        'Alergeni',
        'Informațiile despre alergeni sunt orientative („Poate conține”). Dacă ai alergii sau restricții alimentare, întreabă magazinul înainte de ridicare și nu consuma produsele despre care nu ești sigur.',
      ),
      (
        'Rezervare, ridicare și anulare',
        'După confirmarea comenzii primești un cod de ridicare. Prezintă codul la magazin în intervalul afișat. Poți anula comanda înainte de ridicare, din pagina comenzii. Magazinul poate anula o comandă dacă nu o mai poate onora; în acest caz ești informat în aplicație.',
      ),
      (
        'Plata',
        'În perioada de testare nu se procesează plăți online. Ofertele marcate DEMO sunt demonstrative și nu presupun plată sau ridicare reală. Când plata va fi disponibilă, condițiile vor fi publicate în acest document.',
      ),
      (
        'Magazinele partenere',
        'Magazinele își creează un profil, care este verificat înainte ca ofertele să devină vizibile clienților. Magazinele răspund de corectitudinea informațiilor publicate: denumire, adresă, interval de ridicare, preț și alergeni.',
      ),
      (
        'Utilizare corectă',
        'Nu folosi Wasteless pentru a publica informații false, pentru a rezerva fără intenția de a ridica sau pentru a încerca accesul la conturile altor persoane. Putem suspenda conturile care încalcă aceste reguli.',
      ),
      (
        'Modificări',
        'Putem actualiza acești termeni. Modificările importante vor fi anunțate în aplicație înainte să intre în vigoare.',
      ),
      (
        'Contact',
        'Datele de contact ale operatorului vor fi publicate aici înainte de lansarea publică.',
      ),
    ],
  );
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) => const LegalPage(
    title: 'Politica de confidențialitate',
    summary: 'Ce date folosim, de ce și ce drepturi ai.',
    sections: [
      (
        'Ce date folosim',
        'Pentru clienți: adresa de email, numele (dacă îl completezi), comenzile, coșul și ofertele salvate. Pentru magazine: datele profilului (denumire, adresă, coordonate, interval de ridicare, fotografie) și ofertele publicate.',
      ),
      (
        'Locația',
        'Dacă alegi „Folosește locația mea”, locația este folosită doar pe dispozitivul tău, pentru a calcula distanța până la magazine. Nu o trimitem serverelor Wasteless și nu o păstrăm.',
      ),
      (
        'De ce le folosim',
        'Pentru a-ți crea contul, a procesa rezervările, a-ți arăta codul de ridicare și a permite magazinului să onoreze comanda. Temeiul este executarea serviciului pe care îl soliciți.',
      ),
      (
        'Cu cine le împărțim',
        'Magazinul de la care rezervi vede comanda ta, fără adresa de email. Folosim furnizori pentru autentificare, bază de date și stocarea fotografiilor (Supabase), găzduire (Render) și hărți (OpenStreetMap, care primește adresa IP la afișarea hărții). Nu vindem datele tale.',
      ),
      (
        'Stocare locală',
        'Aplicația păstrează pe dispozitiv sesiunea de autentificare și preferințele tale (de exemplu orașul și animațiile reduse). Nu folosim cookie-uri de publicitate.',
      ),
      (
        'Cât timp le păstrăm',
        'Cât timp contul este activ. Istoricul comenzilor poate fi păstrat mai mult dacă legea o cere, de exemplu pentru evidențe contabile, după ce plățile vor fi disponibile.',
      ),
      (
        'Drepturile tale',
        'Ai dreptul de acces, rectificare, ștergere, restricționare, portabilitate și opoziție. Le poți exercita la datele de contact ale operatorului, care vor fi publicate aici înainte de lansarea publică. Ai și dreptul de a depune o plângere la Autoritatea Națională de Supraveghere a Prelucrării Datelor cu Caracter Personal (ANSPDCP).',
      ),
      (
        'Securitate',
        'Accesul la date este limitat pe cont: fiecare utilizator își vede doar propriile comenzi, coșul și ofertele salvate, iar fiecare magazin doar comenzile primite.',
      ),
    ],
  );
}
