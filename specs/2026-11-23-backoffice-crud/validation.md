# Phase 14b — Validation : CRUD complet du back-office

## Résultat

CRUD complet opérationnel dans le back-office : liste, détail, import, bascule
gratuit/payant, édition des métadonnées et suppression réversible. Le scénario
visuel rejoue tout le cycle dans Chrome avec vérification des hashs de
téléchargement et zéro erreur navigateur.

## Tests automatisés

```text
python -m pytest server/tests tools/content/tests -q
159 passed, 1 warning (147 serveur + 12 outils)
```

17 tests ajoutés par rapport à la phase 14 (116) :

- `server/tests/test_admin_books.py` (+2, 5 au total) : page de détail avec
  métadonnées et chapitres, 404 pour un livre inconnu, lien « Détails » dans la
  liste.
- `server/tests/test_admin_edit.py` (10) : formulaire prérempli ; mise à jour de
  la base, du manifeste publié et du catalogue ; reconstruction du descripteur
  avec téléchargement de chaque fichier et vérification taille + SHA-256 ;
  refus d'un titre vide, d'une description > 1 000 caractères, d'un accès
  inconnu, d'un niveau hors `a2`/`b1`/`b2` (normalisation en minuscules) ; 404,
  CSRF (403), session (303).
- `server/tests/test_admin_delete.py` (6) : confirmation par identifiant exact
  (aucune suppression sinon) ; archivage du dossier + suppression de la ligne +
  disparition du catalogue, du manifeste et de la fiche ; suppression possible
  quand le dossier de pack a déjà disparu ; 404, CSRF (403), session (303).

`node --check tools/visual/admin_crud.mjs` passe. Les tests utilisent
exclusivement `tmp_path` ; `server/data` n'est jamais touché.

## Non-régression client

```text
flutter analyze  → No issues found! (245 s)
flutter test     → 286 tests, All tests passed! (1 min 59 s)
```

Le back-office ne touche ni aux routes publiques ni au client Flutter ; ces
exécutions confirment l'absence de régression côté application.

## Scénario visuel sur serveur scratch

Serveur `uvicorn` sur `127.0.0.1:8765`, base et packs dans `.tmp/phase14-admin`,
Chrome 158 visible en débogage sur `9223` :

```bash
BASE_URL=http://127.0.0.1:8765 CDP_URL=http://127.0.0.1:9223 \
ADMIN_TOKEN=local-admin-token-0123456789 node tools/visual/admin_crud.mjs
```

Sortie :

```text
base http://127.0.0.1:8765 — chrome http://127.0.0.1:9223
création : pack visual-crud importé
capture 01-login.png
capture 02-list-after-create.png
capture 03-detail.png
capture 04-edit-form.png
mise à jour : formulaire soumis
descripteur de téléchargement cohérent
capture 05-detail-after-update.png
capture 06-list-after-delete.png
suppression : pack archivé et livre retiré
OK — captures dans .tmp/visual
```

Étapes couvertes :

1. connexion HTTP (cookie de session), import de
   `tools/visual/fixtures/visual-crud.zip` (653 octets), vérification du
   manifeste servi ;
2. captures de la liste et du détail après création ;
3. connexion dans le navigateur, formulaire d'édition rempli (titre « Visual
   CRUD modifié », auteur « Studio Visuel », niveau B1, accès payant), soumission
   puis vérification du manifeste et du catalogue ;
4. téléchargement de chaque fichier listé dans `.download.json` avec contrôle
   de taille et SHA-256 ;
5. suppression via l'interface (confirmation par identifiant), vérification du
   404 sur `/v1/books/visual-crud` et de l'absence dans `/v1/catalogue` ;
6. aucune exception, erreur console ou erreur réseau dans le navigateur.

Captures : `.tmp/visual/01-login.png`, `02-list-after-create.png`,
`03-detail.png`, `04-edit-form.png`, `05-detail-after-update.png`,
`06-list-after-delete.png`. Le dossier de pack a bien été déplacé dans
`.tmp/phase14-admin/packs/.deleted/` (ex.
`visual-crud-20261124T204238Z-343fbd21`) et la liste n'affiche plus que
Sleepy Hollow.

## Scénario mobile sur émulateur Android

Le parcours back-office → application est revérifié sur un émulateur Android
réel, sans passer par la vue mobile web. Prérequis : un AVD démarré, l'APK
debug installé avec `API_BASE_URL=http://10.0.2.2:8000`, le serveur scratch sur
`127.0.0.1:8766` et un relais `8000 → 8766` (ou un APK reconstruit contre le
port 8766). Le serveur doit tourner avec `STORYLINGO_ADMIN_TOKEN` et des packs
dans `.tmp/`, jamais dans `server/data`.

```bash
ADB="$ANDROID_HOME/platform-tools/adb" ADMIN_TOKEN=local-admin-token-0123456789 \
  node tools/visual/android_visibility.mjs
```

Le script enchaîne, sans intervention manuelle :

1. connexion HTTP au back-office et import de
   `tools/visual/fixtures/visual-crud.zip` (gratuit), après suppression d'un
   éventuel pack de test résiduel ;
2. remise à zéro des données de l'app (`pm clear`), injection des préférences
   minimales (onboarding terminé, niveau A2, thème clair) via `run-as`, puis
   démarrage de `com.storylingo.storylingo/.MainActivity` ;
3. ouverture de l'onglet Bibliothèque : « Visual CRUD », « CRUD visuel » et la
   description sont visibles ; capture `android-10-library-uploaded.png` ;
4. ouverture du chapitre : « Un matin » et « Hello visual world. » s'affichent
   dans le lecteur ; capture `android-11-reader-uploaded.png` ;
5. édition via le back-office (titre « Visual CRUD mobile », auteur « Studio
   Mobile », B1), redémarrage de l'app : le nouveau titre et l'auteur sont
   visibles ; capture `android-12-library-edited.png` ;
6. suppression via le back-office, redémarrage : le livre a disparu de la
   bibliothèque, Sleepy Hollow reste affiché ; capture
   `android-13-library-after-delete.png`.

Si le premier chargement du catalogue échoue (démarrage à froid), le script
appuie sur « Actualiser le catalogue » avant de conclure à un échec. Aucun
émulateur ni appareil physique n'est requis en CI : le scénario reste manuel et
confiné à `127.0.0.1` / `10.0.2.2`.

## Comportements vérifiés

- Édition : le pack est republié via `publish_pack` sur une copie temporaire ;
  le descripteur est reconstruit et reste cohérent pour le hors-ligne.
- Suppression : archivage réversible dans `<content_dir>/.deleted/`, puis
  suppression SQL ; restauration du dossier si la transaction échoue.
  `.deleted/` n'est pas purgé par le nettoyage des répertoires temporaires.
- Confirmation par identifiant exact, CSRF et session exigés sur chaque
  mutation ; valeurs de manifeste échappées dans les vues.
- Aucun secret dans le dépôt ; token visuel fourni par variable
  d'environnement ; Chrome et serveur de test confinés à `127.0.0.1`.

## Limites assumées

- Pas de restauration depuis l'interface ; une archive se restaure à la main.
- Pas d'édition des chapitres ni de l'audio, pas d'historique d'audit en base.
- Un seul administrateur ; périmètre réseau du back-office inchangé.
