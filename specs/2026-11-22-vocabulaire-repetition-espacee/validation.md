# Phase 7 Validation — Vocabulaire & répétition espacée

## Definition of Done

Tout ce qui suit doit être vrai avant fusion.

### 1. Analyse statique

```
flutter analyze
```

Doit sortir en code 0, sans erreur ni avertissement.

### 2. Tests automatisés

```
flutter test
```

Tous les tests passent, y compris ceux des phases 1 à 6.

Tests requis :

- **FSRS / file** : note « Facile » → échéance plus lointaine que « Bien » sur une carte neuve ; cartes non dues exclues ; cartes nouvelles en tête ; objectif quotidien respecté (10 max, reste du jour) ; cartes dues déjà révisées non plafonnées ; « À revoir » re-proposé une seule fois.
- **Détection** : nom propre exclu ; mot sous le niveau utilisateur exclu (sauf enregistré) ; mot au niveau ou au-dessus retenu ; complément au minimum de 5 ; mot enregistré prioritaire ; mots déjà introduits exclus.
- **Stockage** : aller-retour JSON complet (fiche + état FSRS + dates) ; entrées invalides ignorées ; déduplication ; persistance relue par un nouveau repository ; seule `srs.cards` ajoutée ; `prefs.version` reste `1`.
- **Widget** : révision d'une carte (verso, quatre notes, passage à la suivante) ; fin de séance ; séance vide ; prononciation appelée avec le clip du pack ; fin de chapitre → cartes créées + CTA vers la révision ; écran « Aujourd'hui » (X/10, cartes dues, CTA) ; 360 px sans overflow ; non-régression des tests existants.

### 3. Contenu et préférences

- `packVersion` du pack pilote = `1.2.0` ; `schemaVersion` du chapitre reste `2`.
- Champ `cefr` optionnel accepté et ignoré s'il est absent (rétrocompatibilité).
- `prefs.version` reste à `1` ; seule `srs.cards` s'ajoute.
- Aucune modification du manifeste Android.

### 4. Fin de chapitre et détection

- « Terminer le chapitre » crée des cartes pour les mots du chapitre non encore introduits.
- Les noms propres ne deviennent pas des cartes.
- Un mot enregistré dans « Ma liste de mots » est introduit même si son niveau est inférieur à celui de l'utilisateur.
- Terminer deux fois le chapitre ne crée aucun doublon.
- Le récapitulatif affiche le nombre de mots ajoutés et le nombre de cartes prêtes.

### 5. Séance de révision

- Recto : mot, phonétique, nature, « Écouter » ; verso : traduction, définition, exemple.
- Les quatre notes reprogramment la carte et passent à la suivante.
- « À revoir » re-propose la carte au plus une fois.
- La fin de séance affiche le nombre de mots revus et permet de revenir.
- Sans carte due : état vide explicite.
- Fermer l'écran arrête la prononciation.

### 6. Objectif quotidien

- Les 10 premières cartes jamais révisées du jour sont proposées ; les suivantes attendent le lendemain.
- Le compteur « Nouveaux mots : X/10 » reflète les premières notes du jour local.
- Les cartes échues déjà révisées sont toujours proposées et n'incrémentent pas X.

### 7. Hors-ligne

- En mode avion : fin de chapitre, création des cartes, révision, notes et persistance fonctionnent.
- Aucun appel réseau n'est introduit.

### 8. Accessibilité et ergonomie

- Boutons de note et « Écouter » ≥ 44 × 44 px.
- Libellés : « Afficher la réponse », « À revoir », « Difficile », « Bien », « Facile », « Réviser mes mots ».
- Contraste suffisant en thème clair et sombre ; aucune overflow à 360 px.

### 9. CI

Le workflow existant reste vert : `flutter pub get`, `flutter analyze`, `flutter test`.

### 10. Aperçu visuel

Captures Chrome : carte recto, carte verso, fin de séance, carte « Vos mots du jour » sur « Aujourd'hui » (thème clair et sombre). Archives `.tmp/screens/web-*.png`.

### 11. Runtime Android

Sur l'émulateur existant (`storylingo_api36`) :

- terminer le chapitre crée les cartes et le récapitulatif propose la révision ;
- une séance complète se déroule du recto à la fin, avec les quatre notes ;
- les échéances et l'historique survivent à un redémarrage de l'application ;
- la limite de 10 nouveaux mots par jour est observée ;
- en mode avion, la révision et la prononciation fonctionnent ;
- captures archivées dans `.tmp/screens/android-*.png`.

## Not Required

- Streak, badges, statistiques détaillées, parcours 28 jours (phase 8).
- Listes CEFR complètes et détection des tokens non annotés (phase 10).
- Réglage de l'objectif quotidien, révisions inversées ou saisies libres.
- Synchronisation cloud et migrations SQLite.
