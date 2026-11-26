# Phase 16 — Analytics, notifications & release

## Contexte

Les phases 1 à 15 livrent la boucle complète : onboarding, lecture, audio,
vocabulaire, programme 28 jours, comptes, hors-ligne, freemium et paiement
mobile money. La télémétrie existe déjà mais uniquement en local
(`features/telemetry`), exportable en JSON depuis les réglages pour le pilote.

Cette phase branche l'instrumentation produit (Mixpanel), ajoute le rappel
quotidien doux promis par la mission, audite l'accessibilité et la performance
du lecteur, puis prépare une version distribuable (Play internal ; TestFlight
préparé, non exécuté faute de Mac).

Le design cible est livré par la phase 16a (refonte visuelle mobile & web,
`specs/2026-11-26-refonte-visuelle-mobile-web/`), exécutée avant celle-ci :
l'audit d'accessibilité, les mesures de performance et la release portent sur
cette interface.

## Décisions de cadrage

- **Analytics côté client uniquement** dans cette phase. Les événements
  serveur Mixpanel (webhooks de paiement, entitlements) sont différés : le
  backend ne connaît pas le consentement de l'appareil.
- **Consentement explicite (RGPD, opt-in)** avant tout envoi réseau. Aucun
  événement n'est mis en file pour un envoi rétroactif : refuser ou accepter
  plus tard ne rejoue pas l'historique local.
- **Identité pseudonyme** : `distinct_id` = UUID v4 généré localement au
  premier lancement. Jamais d'email, de téléphone, de nom, d'identifiant
  Supabase ni de contenu de lecture dans les événements.
- **Projet Mixpanel en résidence UE**, événements automatiques désactivés
  (`trackAutomaticEvents: false`), géolocalisation par IP désactivée
  (`useIpAddressForGeolocation: false`).
- **Un seul point d'émission** : `TelemetryController.record` reste l'API
  d'enregistrement ; il persiste l'événement local puis le transmet au sink
  analytics (si consentement et jeton présents). L'export local du pilote
  continue de fonctionner à l'identique.
- **Notifications locales uniquement** (`flutter_local_notifications` +
  `timezone`) : pas de FCM ni de push distant dans cette phase.
- **Rappel inactif par défaut** ; l'activation demande la permission système.
  Une seule notification par jour, ton positif, jamais de relance.
- **Planification inexacte** (`inexactAllowWhileIdle`) : pas de permission
  d'alarme exacte, dérive de quelques minutes acceptée.
- **Release Android d'abord** : AAB signé + procédure Play internal. La
  soumission aux stores et TestFlight dépendent de comptes externes et d'un
  Mac : hors périmètre exécutable, préparés en documentation.
- Le paiement mobile money reste désactivé en release
  (`MOBILE_MONEY_ENABLED` absent) ; c'est une contrainte de politique store.

## Périmètre

### 1. Consentement et analytics

- Nouvelle carte de consentement sur « Aujourd'hui », affichée tant que le
  choix n'a pas été fait (après l'onboarding) :
  - titre : « Aidez-nous à améliorer Storylingo » ;
  - texte : statistiques d'usage anonymes (écrans, sessions, conversions),
    jamais le contenu lu ni de données personnelles ;
  - actions « Partager » / « Non merci », choix mémorisé.
- Réglages > section « Confidentialité » : interrupteur « Partager des
  statistiques d'usage » (modifiable à tout moment, effet immédiat).
- Sans `MIXPANEL_TOKEN` (`--dart-define`), aucun réseau analytics n'est émis,
  même avec consentement : l'app reste pleinement fonctionnelle.
- Abstraction `AnalyticsSink` (interface) + implémentation Mixpanel + fake de
  test ; initialisation au démarrage et bascule à chaud au changement de
  consentement. Toute erreur analytics est avalée (jamais bloquante).

### 2. Contrat d'événements

Les noms existants de la télémétrie locale sont réutilisés tels quels.

| Événement | Moment | Propriétés |
| --- | --- | --- |
| `app_opened` | ouverture de l'app | `level`, `onboardingCompleted` |
| `onboarding_completed` | fin de l'onboarding (nouveau) | `level`, `interestsCount` |
| `chapter_started` | entrée dans un chapitre | `chapterId`, `chapterNumber` |
| `chapter_completed` | fin de chapitre | `chapterId`, `chapterNumber`, `minutes`, `newWords`, `programDay` |
| `review_started` | ouverture d'une révision | `queueSize` |
| `review_completed` | fin de révision | `reviewed`, `again`, `hard`, `good`, `easy`, `queueSize` |
| `paywall_viewed` | affichage du paywall (nouveau) | `source` (`settings`, `locked_book`, `library`), `entitlementActive` |
| `purchase_started` | lancement d'un achat (nouveau) | `productId`, `provider` (`revenuecat`, `moneyfusion`) |
| `purchase_completed` | entitlement actif (nouveau) | `productId`, `provider` |
| `purchase_failed` | refus, annulation, erreur (nouveau) | `productId`, `provider`, `reason` (`refused`, `cancelled`, `network`) |
| `reminder_enabled` | activation du rappel (nouveau) | `minuteOfDay` |
| `reminder_opened` | ouverture depuis la notification (nouveau) | — |
| `analytics_consent_granted` | consentement accepté (nouveau) | — |

- Propriétés primitives uniquement (String, num, bool), via
  `sanitizeTelemetryProperties`.
- Aucun événement ne contient d'email, téléphone, nom, texte du livre,
  définition, ni `distinct_id` en propriété (l'identité est portée par
  `identify`).

### 3. Rappel quotidien doux

- Réglages > section « Rappel quotidien » : interrupteur + heure (TimePicker,
  défaut 18:00). Préférences : `reminders.enabled` (bool),
  `reminders.minute_of_day` (int).
- À l'activation : demande de permission (Android 13+ `POST_NOTIFICATIONS`,
  iOS `requestAuthorization`). Refus → l'interrupteur reste désactivé avec un
  message explicite ; aucun rappel planifié.
- Contenu : rotation de trois messages non culpabilisants (par jour) :
  - « Un chapitre vous attend : sept minutes suffisent. »
  - « Reprenez l'histoire là où vous l'avez laissée. »
  - « Votre prochain chapitre est prêt, à votre rythme. »
- Planification : une occurrence à la fois (identifiant fixe), reprogrammée
  au démarrage, au changement d'heure, et après la complétion du jour.
  Objectif du jour atteint → pas de rappel aujourd'hui, prochaine occurrence
  demain.
- Bouton « Envoyer un exemple » dans les réglages (visible si activé) pour la
  démonstration.
- Tap sur la notification (app ouverte ou démarrage à froid) → route
  `/today`, et `reminder_opened` est enregistré.
- Changement de fuseau horaire : reprogrammation au prochain démarrage.

### 4. Audit accessibilité et performance

Écrans audités : lecteur (lecture, transport audio, fin de chapitre),
« Aujourd'hui », paywall, formulaire mobile money, réglages.

Accessibilité :

- Libellés sémantiques sur tous les boutons icône (signet, réglages, lecture,
  pause, fermeture, téléchargement, transport audio) et sur les contrôles de
  progression.
- Cibles tactiles ≥ 48×48 dp.
- Contraste : corps de texte ≥ 4,5:1, grands textes et icônes ≥ 3:1, en clair
  et en sombre.
- Texte agrandi jusqu'à 200 % sans débordement ni perte d'action sur ces
  écrans ; tests widget à `textScaler` 1,3 / 1,6 / 2,0.
- Parcours TalkBack des écrans cœur sans élément non annoncé ni piège de
  focus ; ordre de lecture cohérent.

Performance (mode `--profile` sur l'émulateur `demo36`) :

- démarrage à froid ≤ 4 s ;
- ouverture d'un chapitre ≤ 1 s ;
- 10 s de défilement du lecteur sans frame > 32 ms ;
- surlignage karaoké aligné sur l'audio à ±200 ms sur 3 minutes ;
- mémoire stable sur une session de 20 minutes (pas de fuite visible).
- Les mesures et les corrections appliquées sont consignées dans
  `validation.md` ; une mesure hors seuil non corrigée y est justifiée.

### 5. Distribution interne

- Version `1.0.0+1` (premier envoi interne).
- Android : configuration de signature release par `key.properties` (non
  versionné ; keystore hors dépôt), `flutter build appbundle --release`
  vérifié, `.gitignore` complété (`key.properties`, `*.jks`, `*.keystore`).
- Sans `API_BASE_URL`, l'AAB interne fonctionne en mode hors-ligne complet ;
  avec `API_BASE_URL`, il vise l'API de démonstration. `MOBILE_MONEY_ENABLED`
  n'est jamais défini en release.
- Documentation `README` : génération du keystore, build AAB, création de
  l'application et de la piste « internal testing » dans Play Console,
  liste de testeurs, mise à jour de version.
- iOS : préparation documentaire uniquement (bundle id
  `com.storylingo.storylingo`, signature Apple requise). Aucun build IPA sans
  Mac.
- Fiche de soumission stores : checklist des prérequis restants (URL de
  politique de confidentialité, captures, classification, compte
  développeur). La soumission réelle est hors périmètre.

### 6. Documentation et tests

- `README` : sections « Analytics & confidentialité », « Rappel quotidien »,
  « Build release Android ».
- Tests :
  - analytics : mapping des événements, gating consentement/jeton, absence de
    PII, changement d'état à chaud, erreurs avalées ;
  - rappel : activation/refus de permission, planification/annulation,
    objectif atteint, payload de tap, reprogrammation au changement d'heure ;
  - accessibilité : tests widget de mise à l'échelle du texte et de libellés
    sémantiques sur les écrans cœur ;
  - existants : `flutter test` et `pytest` restent verts (aucun changement
    serveur attendu).

## Hors périmètre

- Événements Mixpanel côté serveur et identité unifiée client ↔ serveur.
- Push distant (FCM), campagnes, A/B testing, consentement granulaire par
  finalité.
- Exécution TestFlight / build iOS (pas de Mac), soumission App Store et Play
  Store, gestion des comptes développeur.
- Audit exhaustif de tous les écrans (couverture limitée aux écrans cœur).
- Politique de confidentialité rédigée et publiée.
- CI (toujours différé).
- Modification du serveur, du package `money_fusion` ou du paiement mobile
  money.

## Risques et parades

- **Dérive RGPD** : tout nouvel événement passe par la table ci-dessus ; un
  test vérifie qu'aucune propriété personnelle ne peut être émise.
- **Bruit de notifications** : une occurrence unique par jour, annulée dès
  l'objectif atteint ; ton jamais culpabilisant.
- **Permissions refusées** : le rappel reste indisponible sans blocage de
  l'app ; message d'explication et réglages système.
- **Dérive de planification** : reprogrammation systématique au démarrage ;
  mode inexact assumé.
- **Fuite de secrets de signature** : keystore et `key.properties` hors
  dépôt, `.gitignore` mis à jour, contrôle avant commit.
- **Mesures de performance non reproductibles** : protocole fixé (profile,
  `demo36`) et consigné ; seuils documentés plutôt que cachés.

## Références

- `specs/mission.md` (rappels doux, KPIs de rétention, tone of voice)
- `specs/tech-stack.md` (Mixpanel client + serveur, notifications locales)
- `specs/roadmap.md` (phase 16)
- `lib/features/telemetry/` (événements locaux existants)
- `specs/2026-11-26-refonte-visuelle-mobile-web/` (design livré en phase 16a,
  prérequis de l'audit et de la release)
