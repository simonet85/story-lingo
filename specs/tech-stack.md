# Tech Stack

Storylingo est une application mobile **Flutter** adossée à une API **Python FastAPI** et à **PostgreSQL**. Le client est *offline-first* : contenu, progression et répétition espacée vivent dans une base locale et sont synchronisés avec le serveur quand le réseau le permet.

## Client mobile

| Couche | Choix | Justification |
|---|---|---|
| Langage & UI | **Flutter / Dart** | Un seul codebase iOS + Android ; contrôle total du rendu pour le lecteur immersif et le surlignage karaoké |
| Design system | Material 3 + thème custom | Cohérence des composants, thème clair/sombre via `ThemeMode` |
| État | **Riverpod** | Testable, découplé du `BuildContext`, adapté aux flux de lecture et de session |
| Navigation | `go_router` | Deep links (reprise de lecture, rappel quotidien) |
| Audio | `just_audio` (+ `just_audio_background`) | Vitesse 0.8x–1.5x, position précise au mot près pour la synchronisation |
| Base locale | **drift (SQLite)** | Schéma typé, migrations, requêtes réactives pour progression et SRS |
| SRS | **FSRS** exécuté en local | Planification de révision moderne, sans dépendance réseau |
| Notifications | `firebase_messaging` + `flutter_local_notifications` | Rappel quotidien doux, heure locale |
| Paiements | **RevenueCat** | Abonnements et restauration d'achats iOS/Android sans dupliquer la logique |

### Synchronisation texte ↔ audio

Les timings mot → offset audio sont calculés **hors ligne par le pipeline de contenu** et embarqués dans le pack du livre. L'application ne réalise aucun alignement forcé à la volée : elle lit un index de timings, ce qui rend le karaoké fluide même sur un appareil modeste.

## Backend

| Couche | Choix | Justification |
|---|---|---|
| Langage | **Python 3.12 + FastAPI + Pydantic v2** | Cœur métier lexical (annotation CEFR, détection de mots nouveaux) natif en Python ; API typée et OpenAPI gratuite |
| Base de données | **PostgreSQL** managé | Relationnel pour catalogue, utilisateurs, progression ; recherche plein texte si besoin |
| Hébergement DB/Auth/Storage | Supabase Postgres + Auth + Storage en early stage | Services managés (auth, stockage) sans enfermer l'API métier, qui reste FastAPI |
| API | REST versionnée (`/v1`), OpenAPI généré | Simple, cacheable, contrat stable pour le client |
| Auth | JWT Supabase vérifiés par FastAPI | Email + fournisseurs sociaux ; le serveur reste la seule autorité sur les entitlements |
| Audio | Stockage S3-compatible (Supabase Storage ou Cloudflare R2) derrière **CDN** | Streaming par plage d'octets + téléchargement hors-ligne |
| Pipeline de contenu | Scripts Python + file légère (`arq` + Redis) | Ingestion EPUB, découpage en chapitres, annotation CEFR, génération des timings, publication de packs |
| Analytics | **Mixpanel** (événements client + serveur) | Funnels onboarding → J1 → J7 → J28 ; aucun contenu personnel dans les événements |
| Observabilité | Sentry (app + API), logs JSON structurés | Diagnostic rapide des erreurs de lecture et de sync |

## Format de contenu

- Packs **versionnés et signés** : manifest, chapitres JSON (texte tokenisé, mots annotés, timings), audio, médias.
- Téléchargement et mise à jour **atomiques** ; vérification d'intégrité avant activation.
- L'accès premium est contrôlé par *entitlement*, pas par DRM propriétaire : URLs CDN signées pour le streaming, packs autorisés par le serveur pour le hors-ligne.

## Synchronisation

- La base locale est la **source de vérité pendant la session** ; le serveur converge ensuite.
- Synchronisation différentielle (push/pull) par entités : progression, positions de lecture, états SRS, préférences.
- Résolution de conflits **last-write-wins par horodatage serveur**, suffisante pour un usage mono-utilisateur multi-appareils.

## Tests & outillage

- **Client** : `flutter test`, `integration_test`, golden tests sur le lecteur et le karaoké.
- **API** : `pytest` + `httpx`, PostgreSQL via testcontainers.
- **Lint/format** : `flutter_lints` + `dart format` ; `ruff` + `mypy`.
- **CI** : GitHub Actions — build et tests Flutter, tests API, génération des packs de test.
- **Dev local** : `docker compose` (PostgreSQL, Redis), `uvicorn --reload`.

## Ce que nous ne faisons pas (et pourquoi)

- **Pas de React Native** : Flutter est choisi pour la cohérence du rendu et l'écosystème audio/offline.
- **Pas de microservices** : un seul service FastAPI ; le pipeline de contenu est un job, pas un service.
- **Pas de SRS maison** : FSRS plutôt qu'une heuristique improvisée.
- **Pas de ML lourd sur l'appareil** : la détection de mots nouveaux est un rapprochement lexical contre des listes CEFR annotées, pas un modèle embarqué.
- **Pas de web app au MVP** : priorité iOS + Android ; l'administration du contenu se fait par CLI.
- **Pas d'analytics maison** : Mixpanel couvre les besoins du MVP.
