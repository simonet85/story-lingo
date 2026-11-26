# Phase 16 Validation — Analytics, notifications & release

## Definition of Done

Tout ce qui suit doit être vrai avant de fusionner la branche dans `main`.

### 1. Le socle analytics respecte jeton et consentement

- sans `MIXPANEL_TOKEN`, aucun appel réseau analytics (vérifié par test avec
  sink factice et par absence de trafic dans `logcat`) ;
- consentement non renseigné ou refusé → aucun envoi, événements locaux
  conservés ;
- accepter plus tard n'envoie pas l'historique local rétroactif ;
- l'interrupteur « Partager des statistiques d'usage » bascule à chaud ;
- aucune erreur analytics ne remonte à l'interface.

### 2. L'identité est pseudonyme et sans PII

- `distinct_id` = UUID v4 généré localement, stable entre lancements ;
- aucun événement ni propriété ne contient email, téléphone, nom,
  identifiant Supabase, texte de lecture ni définition ;
- test unitaire dédié sur le nettoyage des propriétés ;
- Mixpanel initialisé sans événements automatiques, sans géolocalisation IP,
  projet en résidence UE.

### 3. Le contrat d'événements est conforme

- les noms et propriétés de la table de `requirements.md` sont émis aux
  moments prévus (`app_opened`, `onboarding_completed`, `chapter_*`,
  `review_*`, `paywall_viewed`, `purchase_*`, `reminder_*`,
  `analytics_consent_granted`) ;
- les événements existants (`app_opened`, `chapter_started`,
  `chapter_completed`, `review_started`, `review_completed`) restent
  inchangés dans l'export local du pilote ;
- `flutter test` couvre le mapping exact.

### 4. Le rappel quotidien est doux et contrôlable

- inactif par défaut ; activation via l'interrupteur des réglages ;
- permission refusée → aucun rappel planifié, message explicite, interrupteur
  désactivé ;
- une seule occurrence par jour, ton positif (trois messages en rotation) ;
- changement d'heure persisté et reprogrammé ;
- bouton « Envoyer un exemple » opérationnel ;
- aucune relance le jour où l'objectif est atteint.

### 5. Le tap sur la notification cible « Aujourd'hui »

- app ouverte : navigation vers `/today`, `reminder_opened` émis ;
- démarrage à froid : même comportement via
  `getNotificationAppLaunchDetails`.

### 6. L'accessibilité des écrans cœur est vérifiée

Prérequis : la refonte visuelle de la phase 16a est livrée ; l'audit porte
sur ce design, pas sur l'interface antérieure.

- lecteur, transport audio, « Aujourd'hui », paywall, formulaire mobile money
  et réglages : libellés sémantiques présents sur les boutons icône, cibles
  ≥ 48 dp, ordre TalkBack cohérent ;
- texte à 200 % sans débordement ni perte d'action ; tests widget à 1,3 /
  1,6 / 2,0 ;
- contrastes ≥ 4,5:1 (texte) et ≥ 3:1 (large/icônes) en clair et sombre ;
- constats consignés dans `validation.md`.

### 7. Les performances du lecteur sont mesurées

Protocole `--profile` sur `demo36` ; seuils :

- démarrage à froid ≤ 4 s ;
- ouverture de chapitre ≤ 1 s ;
- 10 s de défilement sans frame > 32 ms ;
- surlignage karaoké à ±200 ms sur 3 min ;
- mémoire stable sur 20 min.

Mesures et corrections dans `validation.md` ; tout écart non corrigé est
justifié.

### 8. L'AAB release est signé et reproductible

- version `1.0.0+1` ;
- `flutter build appbundle --release` produit un AAB signé par
  `key.properties` ;
- `key.properties`, keystore et `*.jks` absents du dépôt (`.gitignore`
  vérifié) ;
- l'AAB fonctionne hors-ligne sans `API_BASE_URL` et `MOBILE_MONEY_ENABLED`
  n'est jamais défini en release.

### 9. La procédure Play internal est documentée

`README` : génération du keystore, build, création de l'app et de la piste
« internal testing », ajout des testeurs, incrément de version ; checklist des
prérequis stores restants (politique de confidentialité, captures,
classification, comptes). La soumission réelle et TestFlight restent hors
périmètre.

### 10. Analyses, tests et serveur restent verts

```
flutter analyze
dart format --output=none --set-exit-if-changed <fichiers de la phase>
flutter test
cd server && python -m pytest
```

Code 0 partout ; aucune modification serveur ; CI toujours différé.

> Note : le formatage reste limité aux fichiers de la phase ; 46 fichiers
> antérieurs ne sont pas encore alignés sur Dart 3.14 (dette traitée à part).

## Not Required

- Événements Mixpanel côté serveur, identité unifiée client ↔ serveur
- Push distant (FCM), campagnes, A/B testing, consentement granulaire
- Build IPA / TestFlight (pas de Mac), soumission App Store et Play Store
- Politique de confidentialité rédigée et publiée
- Catalogue de captures d'écran store
- Audit de tous les écrans (couverture limitée aux écrans cœur)
- CI
- Changements de serveur ou du package `money_fusion`

## Résultat de validation

À compléter après implémentation : environnement, tableau des vérifications
automatisées, mesures de performance, constats d'accessibilité (avec
corrections), scénarios émulateur, et conclusion.
