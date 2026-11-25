# Storylingo

> Améliore ton anglais en 28 jours avec des livres adaptés.

Application mobile (iOS + Android) d'apprentissage de l'anglais par lecture et écoute de classiques adaptés, pour francophones A2–B2, en sessions de 7 à 10 minutes par jour.

## Inputs stakeholders

- **Produit** : immersion par *graded readers*, lecture + audio synchronisés, vocabulaire contextualisé, parcours guidé de 28 jours, sessions ultra-courtes.
- **Technique** : iOS + Android, hors-ligne robuste, streaming audio optimisé, analytics produit.
- **Business** : freemium, abonnement premium (bibliothèque illimitée, SRS complet, téléchargements, statistiques détaillées).

## Décisions de la constitution

| Décision | Choix |
|---|---|
| Nom | Storylingo |
| Client mobile | Flutter |
| Backend | Python FastAPI + PostgreSQL (Supabase pour DB/Auth/Storage en early stage) |
| Stratégie de livraison | MVP offline-first : pack pilote embarqué, puis API, comptes et sync |

## Specs

- [Mission](specs/mission.md)
- [Tech stack](specs/tech-stack.md)
- [Roadmap](specs/roadmap.md)
- Feature spec — Fondations & Onboarding (phases 1–2) : [plan](specs/2026-11-21-fondations-onboarding/plan.md) · [requirements](specs/2026-11-21-fondations-onboarding/requirements.md) · [validation](specs/2026-11-21-fondations-onboarding/validation.md)
- Feature spec — Modèle de contenu & pack pilote (phase 3) : [plan](specs/2026-11-21-modele-contenu-pack-pilote/plan.md) · [requirements](specs/2026-11-21-modele-contenu-pack-pilote/requirements.md) · [validation](specs/2026-11-21-modele-contenu-pack-pilote/validation.md)
- Feature spec — Lecteur (phase 4) : [plan](specs/2026-11-21-lecteur/plan.md) · [requirements](specs/2026-11-21-lecteur/requirements.md) · [validation](specs/2026-11-21-lecteur/validation.md)
- Feature spec — Audio & synchronisation karaoké (phase 5) : [plan](specs/2026-11-21-audio-karaoke/plan.md) · [requirements](specs/2026-11-21-audio-karaoke/requirements.md) · [validation](specs/2026-11-21-audio-karaoke/validation.md)
- Feature spec — Dictionnaire au tap (phase 6) : [plan](specs/2026-11-21-dictionnaire-tap/plan.md) · [requirements](specs/2026-11-21-dictionnaire-tap/requirements.md) · [validation](specs/2026-11-21-dictionnaire-tap/validation.md)
- Feature spec — Vocabulaire & répétition espacée (phase 7) : [plan](specs/2026-11-22-vocabulaire-repetition-espacee/plan.md) · [requirements](specs/2026-11-22-vocabulaire-repetition-espacee/requirements.md) · [validation](specs/2026-11-22-vocabulaire-repetition-espacee/validation.md)
- Feature spec — Programme 28 jours (phase 8) : [plan](specs/2026-11-22-programme-28-jours/plan.md) · [requirements](specs/2026-11-22-programme-28-jours/requirements.md) · [validation](specs/2026-11-22-programme-28-jours/validation.md)
- Feature spec — Boucle pilote complète (phase 9) : [plan](specs/2026-11-22-boucle-pilote-complete/plan.md) · [requirements](specs/2026-11-22-boucle-pilote-complete/requirements.md) · [validation](specs/2026-11-22-boucle-pilote-complete/validation.md)
- Feature spec — API contenu & catalogue (phase 10) : [plan](specs/2026-11-22-catalogue-import-epub/plan.md) · [requirements](specs/2026-11-22-catalogue-import-epub/requirements.md) · [validation](specs/2026-11-22-catalogue-import-epub/validation.md)
- Feature spec — Comptes & synchronisation (phase 11) : [plan](specs/2026-11-22-comptes-synchronisation/plan.md) · [requirements](specs/2026-11-22-comptes-synchronisation/requirements.md) · [validation](specs/2026-11-22-comptes-synchronisation/validation.md)
- Feature spec — Hors-ligne complet (phase 12) : [plan](specs/2026-11-22-hors-ligne-complet/plan.md) · [requirements](specs/2026-11-22-hors-ligne-complet/requirements.md) · [validation](specs/2026-11-22-hors-ligne-complet/validation.md)
- Feature spec — Freemium & paywall (phase 13) : [plan](specs/2026-11-22-freemium-paywall/plan.md) · [requirements](specs/2026-11-22-freemium-paywall/requirements.md) · [validation](specs/2026-11-22-freemium-paywall/validation.md)
- Feature spec — Paiement mobile money backend (phase 14) : [plan](specs/2026-11-25-paiement-mobile-money/plan.md) · [requirements](specs/2026-11-25-paiement-mobile-money/requirements.md) · [validation](specs/2026-11-25-paiement-mobile-money/validation.md)
- Feature spec — Paiement mobile money dans l'app (phase 15) : [plan](specs/2026-11-25-paiement-mobile-money-app/plan.md) · [requirements](specs/2026-11-25-paiement-mobile-money-app/requirements.md) · [validation](specs/2026-11-25-paiement-mobile-money-app/validation.md)

## Paiement mobile money (démo Android)

Le paiement mobile money est désactivé par défaut (`MOBILE_MONEY_ENABLED`). Il
cible Android uniquement : vendre un abonnement numérique hors des stores ne
peut pas être publié sur les stores, et iOS n’est pas vérifié. Le package
`money_fusion` est consommé depuis Git, épinglé au tag `v0.3.0`.

Prérequis : serveur local, faux MoneyFusion et émulateur Android. L’alias
`10.0.2.2` désigne la machine hôte vue depuis l’émulateur ; le cleartext HTTP
n’est autorisé qu’en debug (`android/app/src/debug/AndroidManifest.xml`).

```bash
# 1. Serveur (écoute sur toutes les interfaces pour l’émulateur)
export STORYLINGO_DEV_AUTH=1
export STORYLINGO_PUBLIC_BASE_URL=http://10.0.2.2:8000
export STORYLINGO_MONEYFUSION_API_URL=http://127.0.0.1:8091/payments
export STORYLINGO_MONEYFUSION_STATUS_BASE_URL=http://127.0.0.1:8091
python -m uvicorn server.app.main:create_app --factory --host 0.0.0.0 --port 8000

# 2. Faux MoneyFusion (page de paiement, statut, webhook)
dart run tool/fake_moneyfusion/server.dart

# 3. App
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=MOBILE_MONEY_ENABLED=true \
  --dart-define=MONEYFUSION_STATUS_BASE_URL=http://10.0.2.2:8091
```

Se connecter, ouvrir l’abonnement puis « Payer par mobile money ». La page
factice propose « Payer » et « Annuler ». L’activation vient du webhook serveur
(`source = "moneyfusion"`), pas du statut affiché par le checkout. Le faux
serveur n’appelle jamais MoneyFusion et ne journalise ni téléphone ni nom.

iOS, le web et les builds release restent hors périmètre de cette démo.

## Développement

Flutter 3.50.1 (stable). Les dépendances directes sont épinglées dans `pubspec.yaml` et `pubspec.lock` est commité.

```bash
flutter pub get
flutter analyze
flutter test
flutter run              # Android / iOS
flutter run -d chrome    # aperçu rapide de l'UI via la plateforme web
```

La plateforme web est présente uniquement pour l'aperçu local ; les cibles produit restent iOS et Android.

La CI (`.github/workflows/ci.yml`) exécute `flutter analyze` et `flutter test` sur chaque push et pull request.
