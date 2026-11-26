# Plan — Phase 16

Branche : `feature/phase-16-analytics-release` (créée après validation de la spec).

## 1. Consentement et socle analytics

- `pubspec.yaml` : ajouter `mixpanel_flutter` (résolution `flutter pub add`).
- `lib/core/prefs/prefs_keys.dart` : clés `analytics.consent`,
  `analytics.distinct_id`, `reminders.enabled`, `reminders.minute_of_day`.
- `lib/core/prefs/prefs_repository.dart` : lecture/écriture de ces clés
  (consentement nullable, UUID v4 généré à la première lecture, minute par
  défaut 1080).
- `lib/core/config/api_config.dart` : `mixpanelTokenProvider`
  (`String.fromEnvironment('MIXPANEL_TOKEN')`).
- `lib/features/analytics/domain/analytics_sink.dart` : interface
  `AnalyticsSink` (`track`, `identify`, `setEnabled`, `flush`).
- `lib/features/analytics/data/mixpanel_analytics_sink.dart` : adaptateur
  Mixpanel (init UE, `trackAutomaticEvents: false`,
  `useIpAddressForGeolocation: false`, opt-out par défaut tant que le
  consentement est absent, erreurs avalées).
- `lib/features/analytics/presentation/analytics_providers.dart` :
  `analyticsSinkProvider` (fake par défaut si jeton vide), `analyticsConsentProvider`
  (`Notifier` sur la préférence, bascule à chaud, identité pseudonyme).
- `lib/features/analytics/presentation/consent_card.dart` : carte sur
  « Aujourd'hui » (affichée si consentement non renseigné), actions
  « Partager » / « Non merci ».
- `lib/features/today/presentation/today_screen.dart` : insérer la carte en
  tête de liste (si onboarding terminé).
- `lib/features/settings/presentation/settings_screen.dart` : section
  « Confidentialité » avec l'interrupteur de partage.

## 2. Émission des événements

- `lib/features/telemetry/presentation/telemetry_provider.dart` : après
  persistance locale, transmission au `AnalyticsSink` (si consenti) ; toute
  erreur est avalée.
- Nouveaux appels `record` :
  - `onboarding_controller.dart` → `onboarding_completed` ;
  - `paywall_screen.dart` → `paywall_viewed` (source + entitlement) ;
  - `revenuecat_billing_gateway`/paywall et `mobile_money_screen.dart` →
    `purchase_started` / `purchase_completed` / `purchase_failed` ;
  - rappels → `reminder_enabled`, `reminder_opened` ;
  - consentement accepté → `analytics_consent_granted`.
- `test/analytics_test.dart` : mapping exact des propriétés, gating
  jeton/consentement, absence de champs personnels, bascule à chaud, erreurs
  du sink avalées.

## 3. Rappel quotidien doux

- Dépendances : `flutter_local_notifications`, `timezone`, `flutter_timezone`.
- `lib/features/reminders/domain/reminder_settings.dart` : modèle immuable
  (activé, minute du jour) + validations.
- `lib/features/reminders/data/notification_gateway.dart` (+ `_stub` / `_io`) :
  abstraction permission/planification/annulation, implémentation
  `flutter_local_notifications` avec `zonedSchedule` en mode
  `inexactAllowWhileIdle`, canal Android unique, identifiant fixe.
- `lib/features/reminders/application/reminder_scheduler.dart` : calcule la
  prochaine occurrence (demain si objectif du jour atteint), gère permission,
  rotation des trois messages (par jour), reprogrammation au démarrage, à la
  modification d'heure, à l'activation, et à la complétion d'un chapitre.
- `lib/features/reminders/presentation/reminder_providers.dart` : providers
  Riverpod ; hook dans `app.dart`/`main.dart` (démarrage + reprise) et écoute
  de `programProgressProvider`.
- `settings_screen.dart` : section « Rappel quotidien » (interrupteur,
  TimePicker, bouton « Envoyer un exemple »).
- Tap notification → `appRouter.go('/today')` + `reminder_opened`, y compris
  au démarrage à froid (`getNotificationAppLaunchDetails`).
- `test/reminders_test.dart` : activation/refus de permission, message du
  jour, objectif atteint → demain, tap → `/today`, changement d'heure.

## 4. Accessibilité

- Corrections ciblées sur les écrans cœur (lecteur, transport audio,
  « Aujourd'hui », paywall, formulaire mobile money, réglages) : libellés
  sémantiques, cibles ≥ 48 dp, contrastes AA, ordre TalkBack.
- `test/accessibility_test.dart` : tests widget à `textScaler` 1,3 / 1,6 /
  2,0 (aucune exception de débordement, actions principales atteignables) et
  présence des libellés sémantiques des contrôles icône.
- Parcours TalkBack manuel consigné dans `validation.md`.

## 5. Performance

- Protocole : `flutter run --profile` sur `demo36`, mesures DevTools.
- Mesures : démarrage à froid, ouverture de chapitre, 10 s de défilement,
  dérive karaoké sur 3 min, mémoire après 20 min.
- Corrections ciblées si un seuil est dépassé (éviter les reconstructions du
  chapitre au tick du timer, `const`, `RepaintBoundary` si nécessaire).
- Tableau des mesures et écarts dans `validation.md`.

## 6. Distribution

- `pubspec.yaml` : version `1.0.0+1`.
- `android/app/build.gradle.kts` : lecture de `key.properties` pour signer la
  release ; échec explicite si absent hors builds locaux de démonstration.
- `.gitignore` : `key.properties`, `*.jks`, `*.keystore`.
- Génération locale documentée d'un keystore d'upload (`keytool`), stocké
  hors dépôt ; build `flutter build appbundle --release` vérifié.
- `README.md` : sections analytics/confidentialité, rappel quotidien, build
  release Android, Play internal (création d'app, piste, testeurs), prérequis
  stores restants ; note iOS/TestFlight préparé mais non exécuté.

## Vérification

```
flutter analyze
dart format --output=none --set-exit-if-changed <fichiers de la phase>
flutter test
cd server && python -m pytest
flutter build appbundle --release
```

Compléments : événements vérifiés avec un `AnalyticsSink` factice (aucun
envoi réseau en test) ; notifications validées sur `demo36` (heure simulée
avancée ou bouton « Envoyer un exemple ») ; mesures de performance
consignées ; `logcat`/réseau contrôlés pour l'absence de PII ; vérification
`.gitignore` avant commit (aucun keystore ni `key.properties`).

## Livraison

- Commit de la spec sur `feature/phase-16-analytics-release`, puis
  implémentation avec `validation.md` renseigné.
- Fusion fast-forward dans `main`, push, suppression de la branche — uniquement
  sur validation explicite.
- Dette de formatage global (46 fichiers antérieurs) toujours traitée à part ;
  la vérification de formatage reste limitée aux fichiers de la phase.
- CI toujours différé.
