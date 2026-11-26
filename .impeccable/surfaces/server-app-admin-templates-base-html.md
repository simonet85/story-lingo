---
version: 1
slug: "server-app-admin-templates-base-html"
primary_target: "server/app/admin/templates/base.html"
related_targets: ["server/app/admin/templates/login.html","server/app/admin/templates/books.html","server/app/admin/templates/book_detail.html","server/app/admin/templates/book_edit.html","server/app/admin/templates/import.html"]
---

## Scope and mode

Operate. Toutes les pages servies sous `/admin` : connexion, liste des livres, détail, édition et import, dans `server/app/admin/templates/`. La cible primaire est `base.html` (coquille + CSS) ; les cinq gabarits de page en dépendent.

## Audience, job, constraints

Une seule personne éditoriale sur ordinateur, en local ou sur VPN. Tâche : voir ce qui est publié, importer un pack, corriger les métadonnées, basculer gratuit/payant. Usage épisodique, quelques passages par jour. Contraintes : chaque indicateur est dérivé de la base, aucune donnée inventée ; aucune image tierce ; conserver les noms de champs et sélecteurs dont dépendent les tests serveur et le scénario CRUD visuel (`input[name=password]`, `form.edit`, `form.delete`, `name="confirm"`) ; copie en français.

## Chosen direction

Direction épinglée par l'utilisateur : composition de `docs/web-mobile-dashboard.png` (barre latérale de travail, rangée d'indicateurs, recherche, tableau avec pastilles et actions de ligne) fusionnée avec le rythme aéré de `docs/01-web-interface.png` (surfaces crème, contrôles en pilule, lignes confortables). Le monde visuel reste celui de DESIGN.md : papier crème, encre, vert Storylingo, ambre pour l'accès payant. Connexion : panneau scindé, volet vert typographique et carte de formulaire crème.

## Direction contract

THESIS : Le back-office est le bureau du catalogue : on y scanne la bibliothèque publiée d'un seul regard, au lieu d'un en-tête sombre au-dessus d'un tableau HTML brut.

OWN-WORLD : jetons de DESIGN.md — papier #F7F1E6, carte #FFFCF5, encre #1B1F1D, vert Storylingo #2F5D50, sauge douce #D7E6DD, ambre #8A5A16 sur #F6E3C2 ; panneaux 20 px, contrôles 14 px, pastilles 999 px ; une seule sans de travail, échelle fixe, chiffres tabulaires.

STORY : L'éditeur voit d'un coup d'œil combien de livres existent, lesquels sont gratuits, combien de chapitres et de minutes cela représente ; une recherche affine la liste ; chaque ligne mène au détail, à l'édition ou au changement d'accès.

FIRST VIEWPORT : barre latérale crème de 264 px (marque, Livres, Importer, session, déconnexion) et espace de travail de 1180 px : « Bibliothèque » avec sous-titre et action primaire « Importer un pack », quatre cartes d'indicateurs (livres, chapitres, minutes, accès), puis le panneau des livres avec recherche et tableau. La connexion est un panneau scindé : volet vert de marque et carte de formulaire crème.

FORM : dashboard BookScope (barre latérale + indicateurs + tableau) fusionné avec les cartes aérées et les contrôles en pilule de l'interface de lecture, direction épinglée par l'utilisateur avec la palette Storylingo ; seed: none (unavailable).

FINISH : unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.

## Open questions

Aucune : périmètre, indicateurs et traitement de la connexion confirmés par l'utilisateur (tout le back-office, données réelles, panneau scindé).

## Finish review

Verdict : livré. Les six gabarits partagent la même coquille, les mêmes jetons et le même vocabulaire de composants ; le monde de DESIGN.md est étendu aux besoins du back-office (étapes 11–14,5 px, surfaces `--input`, cartes d'indicateurs) plutôt que remplacé.

Vérifié sur les pages servies par l'API locale :

- Connexion 1440 et 390 : panneau scindé, erreur « Mot de passe invalide. », affichage/masquage du jeton (`aria-pressed`, `aria-label`), focus clavier visible (anneau 1,6 px vert).
- Bibliothèque 1440, 768, 390 : indicateurs dérivés de la base (1 livre, 3 chapitres, 18 min, 1 gratuit), recherche « 0 sur 1 livre » avec état vide, tableau transformé en cartes sous 820 px, actions visibles, aucune barre de défilement horizontale de page (`scrollWidth == clientWidth`).
- Détail, édition, import : métadonnées en `dl`, chapitres lisibles, zone de suppression, formulaire prérempli avec entrées de hauteur uniforme, dépôt ZIP et choix d'accès.
- Contrastes AA ou mieux : encre/papier 14,8:1 ; encre douce/carte 7,8:1 ; encre atténuée/papier 5,8:1 ; blanc/vert 7,5:1 ; ambre 10,9:1 ; danger 12,8:1.
- `pytest server/tests` : 149 réussis.
- Détecteur impeccable : 0 échec, 36 notes consultatives — dérive de palette/échelle par rapport au DESIGN.md Flutter (extension assumée du back-office) et un faux positif d'analyse statique sur la couleur héritée des liens de fil d'Ariane.

Captures de contrôle : `adm3_dashboard_1440.png`, `adm3_dashboard_768.png`, `adm2_dashboard_390.png`, `adm2_login_1440.png`, `adm2_login_390.png`, `adm3_edit_1440.png`, `adm3_detail_bottom_1440.png`, `adm3_import_390.png`.
