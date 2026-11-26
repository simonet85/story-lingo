# Validation — Phase 16a : refonte visuelle mobile & web

Statut : à remplir à l'issue de l'implémentation.

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

_(à remplir : environnement, tableau automatisé, contrastes mesurés, scénario
mobile émulateur, scénario web Chrome aux trois largeurs, captures, constats
`impeccable detect`, conclusion.)_
