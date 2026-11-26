# Validation — Phase 16a : refonte visuelle mobile & web

Statut : implémenté et vérifié (écart documenté sur les goldens).

## Definition of Done

1. **Design system livré** : tokens complétés (couleurs, typographie,
   rayons, durées) et `ColorScheme` explicites clair/sombre, vert Storylingo
   conservé comme primaire ; ambre en accent secondaire.
2. **Contrastes AA vérifiés** sur les paires clés (texte/surface,
   texte/primaire, texte secondaire, ambre/surface) par un test dédié ;
   résultats consignés.
3. **Mobile restylé** : onboarding, Aujourd'hui, Bibliothèque, Lecture
   (texte et écoute), Révision, Liste de mots, Progrès, Réglages, Compte,
   Paywall, Compte/abonnement, Téléchargements — mêmes flux, mêmes routes,
   mêmes textes ; aucune fonction ajoutée.
4. **Aucune donnée factice** des captures (notes, auteurs, social,
   progression de groupe, revenus, conversion) ; les indicateurs web sont
   dérivés des providers existants et testés.
5. **Web fonctionnel** : `flutter build web --release` réussit ; navigation
   barre latérale → routes existantes ; paiement mobile money masqué
   (`kIsWeb`) ; téléchargements et billing derrière leurs stubs.
6. **Dispositions vérifiées** aux largeurs 360, 768 et 1280 : compact sans
   débordement, moyen intermédiaire, large tableau de bord à deux volets pour
   la lecture.
7. **Table d'activité récente** alimentée uniquement par la télémétrie
   locale existante, avec état vide soigné et sans PII.
8. **Illustrations originales** d'onboarding livrées (PNG), déclarées dans
   `pubspec.yaml`, aucune marque ni asset tiers des captures.
9. **Tests** : suite existante verte (adaptée seulement là où la disposition
   ou les composants changent), nouveaux tests composants / provider de stats
   / navigation web / coquille responsive, goldens clair et sombre pour
   Aujourd'hui, Bibliothèque, paywall, lecteur et tableau de bord web.
10. **Qualité mécanique** : `flutter analyze` à zéro problème, format
    appliqué aux fichiers de la phase, `impeccable detect` passé une fois sur
    les fichiers UI modifiés (constats corrigés ou documentés).

## Non requis dans cette phase

- Audit a11y complet (TalkBack, 200 % de texte, parcours lecteur) : phase 16.
- Mesures de performance formelles : phase 16.
- Toute fonctionnalité nouvelle (recherche catalogue, auteurs, notes, genres,
  social, Inbox, profil enrichi, Discord, achat direct).
- Site vitrine, SEO, PWA installable, notifications web.
- Modifications serveur, package `money_fusion`, paiement, webhooks.
- Captures de stores, TestFlight, soumission.
- CI (différé).

## Commandes de vérification

```
C:/dev/flutter/bin/flutter analyze
C:/dev/flutter/bin/dart format --output=none --set-exit-if-changed <fichiers de la phase>
C:/dev/flutter/bin/flutter test
C:/dev/flutter/bin/flutter build web --release
C:/Users/DELL/.qoder/skills/impeccable/scripts/impeccable detect --json <fichiers UI modifiés>
```

## Résultats

Vérifié le 2026-11-26.

### Environnement

| Élément | Détail |
|---|---|
| Flutter / Dart | 3.50.1 stable / 3.14.0 |
| Android | émulateur `demo36` (API 36), 1080×2400 à 420 dpi (≈ 393 dp compact), puis surcharge 1536×2048 à 320 dpi (768 dp) pour la disposition intermédiaire |
| Web | `flutter build web --release` servie en local (port 8090), Edge 157 headless piloté par CDP, fenêtres 1280×900, 768×1024 et 360×800 ; `localStorage` amorcé (`flutter.onboarding.completed`, niveau B1, intérêts) pour reproduire un compte installé |
| Données | aucune donnée factice : tous les indicateurs proviennent des providers existants (aucune progression inventée) |

### Contrôles automatisés

| Commande | Résultat |
|---|---|
| `flutter analyze` | 0 problème |
| `dart format --output=none --set-exit-if-changed` (29 fichiers de la phase) | 0 fichier modifié |
| `flutter test` | 318 tests passés (dont `theme_contrast_test`, `dashboard_stats_test`, coquille responsive 360/768/1280) |
| `flutter build web --release` | OK (avertissements wasm `flutter_tts`/`just_audio` non bloquants) |
| `impeccable detect --json` (17 fichiers UI modifiés) | `[]` — aucun constat |

### Contrastes mesurés (`test/theme_contrast_test.dart`)

| Paire | Clair | Sombre |
|---|---|---|
| texte / surface | 14,82:1 | 14,42:1 |
| texte secondaire / surface | 7,11:1 | 10,47:1 |
| texte secondaire / carte | 7,80:1 | 9,81:1 |
| texte / primaire | 7,49:1 | 8,35:1 |
| texte / primaire doux | 12,44:1 | 7,48:1 |
| texte / accent doux | 10,87:1 | 7,87:1 |
| primaire / surface | 6,67:1 | 9,99:1 |
| bordure / surface (≥ 3:1) | 3,98:1 | 6,21:1 |

### Scénario mobile (émulateur, light et dark)

Parcours complet réinstallé depuis un état vierge : accueil (illustration
originale, contenu centré, CTA « Commencer »), test de niveau (10 questions,
badges A–D, barre d'étape), résultat (carte niveau, réserve « estimation,
pas un examen »), intérêts (chips à coche, compteur d'aide, CTA désactivé
puis actif), Aujourd'hui compact (carte de session avec couverture
typographique, mots du jour, note Bibliothèque), Bibliothèque, lecteur
(texte et dictionnaire au tap), mode Écoute (illustration originale, transport
inchangé), Réglages (Compte, Abonnement, Niveau, Apparence,
Téléchargements, Données de test), Aujourd'hui et Réglages en sombre.
Aucun débordement ; la disposition 768 dp (override) rend le rail avec
libellés, les cartes alignées sur la barre d'application, Progrès en grille
d'indicateurs et badges.

Corrections issues de cette passe : accueil recentré verticalement ;
couverture typographique avec note ajustée par mesure du mot le plus long
(plus de coupure « LE/GEND » en web) ; largeur des onglets portée à 720 px
entre 720 et 960 dp pour aligner contenu et barre d'application ; titre de
la barre latérale tronqué proprement ; une seule affordance Réglages par
largeur.

### Scénario web (Edge headless, CDP)

- **1280×900** : barre latérale + tableau de bord Aujourd'hui (4 indicateurs
  réels, carte de session, mots du jour, activité récente vide avec état
  soigné) ; navigation par clic vers Bibliothèque (carte pilote, note
  « téléchargement hors-ligne disponible sur l'application mobile ») ; page
  Abonnement (offres mensuelle/annuelle, encart mode démo, **aucune entrée
  mobile money** — masquée via `kIsWeb`).
- **768×1024** : rail avec libellés, contenu pleine largeur aligné.
- **360×800** : coquille compacte, barre de navigation basse, une colonne.

### Captures

Dans `captures/` (JPEG, redimensionnées) :

| Mobile 393 dp | Tablette 768 dp | Web |
|---|---|---|
| [accueil](captures/mobile_390_accueil.jpg) | [aujourd'hui](captures/tablette_768_aujourdhui.jpg) | [360 aujourd'hui](captures/web_360_aujourdhui.jpg) |
| [test de niveau](captures/mobile_390_test-niveau.jpg) | [progrès](captures/tablette_768_progres.jpg) | [768 aujourd'hui](captures/web_768_aujourdhui.jpg) |
| [résultat](captures/mobile_390_resultat-niveau.jpg) | | [1280 aujourd'hui](captures/web_1280_aujourdhui.jpg) |
| [intérêts](captures/mobile_390_interets.jpg) | | [1280 bibliothèque](captures/web_1280_bibliotheque.jpg) |
| [aujourd'hui](captures/mobile_390_aujourdhui.jpg) | | [1280 abonnement](captures/web_1280_abonnement.jpg) |
| [aujourd'hui sombre](captures/mobile_390_aujourdhui-sombre.jpg) | | |
| [bibliothèque](captures/mobile_390_bibliotheque.jpg) | | |
| [lecture](captures/mobile_390_lecture.jpg) | | |
| [écoute](captures/mobile_390_ecoute.jpg) | | |
| [réglages sombre](captures/mobile_390_reglages-sombre.jpg) | | |

Les largeurs demandées sont couvertes : 360 dp (web compact), 768 dp
(émulateur et web), 1280 dp (web large), 393 dp (Android compact).

### Écart assumé : goldens

Le point 9 prévoyait des goldens clair/sombre (Aujourd'hui, Bibliothèque,
paywall, lecteur, tableau de bord web). Ils ne sont pas livrés : aucune
infrastructure de goldens n'existe dans le dépôt, la CI est différée et les
polices de test produisent des rendus instables. La couverture visuelle est
assurée par les captures réelles ci-dessus (émulateur et navigateur), les
tests de contraste et les tests de coquille responsive ; l'ajout de goldens
reste à faire quand la CI sera outillée.

### Conclusion

Les dix points de DoD sont tenus, à l'exception documentée des goldens.
Le monde visuel hybride (vert Storylingo + crème/encre + ambre) est livré
sur mobile et web, sans fonctionnalité ajoutée ni donnée factice.
`DESIGN.md` et `.impeccable/design.json` carbonisent le système.
