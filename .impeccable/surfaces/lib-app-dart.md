---
version: 1
slug: "lib-app-dart"
primary_target: "lib/app.dart"
related_targets: []
---

# Surface brief — Storylingo (refonte 16a)

Scope : toute l'application (mobile Android/iOS + web). Mode visiteur :
Operate — l'utilisateur complète sa session du jour, lit, écoute, révise.
Aucune fonctionnalité ajoutée ; mêmes routes, mêmes textes, mêmes providers.

## Direction contract

THESIS: Une bibliothèque chaleureuse et éditoriale qui met l'histoire et le
geste du jour au centre ; on refuse l'accueil-dashboard générique saturé de
cartes décoratives et de données factices.

OWN-WORLD: Hybride : vert Storylingo #2F5D50 en primaire, surfaces crème
#F7F1E6 (clair) / encre #101614 (sombre), accent ambre #E4A23C ; cartes à
grand rayon 20–24 avec bordure fine et élévation 0 ; filtres et chips en
pilules ; hiérarchie typographique affirmée (display 32/36, titres 24/28) en
police système ; aucune image de marque tierce.

STORY: L'utilisateur voit immédiatement la session du jour et reprend en un
tap ; il comprend que lire, écouter et réviser forment une seule boucle. Sur
web, il retrouve ses vrais progrès d'un regard et lit en deux volets.

FIRST VIEWPORT: Mobile « Aujourd'hui » : salutation + chip de série, grande
carte de session avec couverture, chapitre, durée et bouton « Continuer » en
pilule ; dessous, mot du jour et carte de progression douce. Web 1280 :
barre latérale à gauche, en-tête, rangée de 4 cartes d'indicateurs réels,
carte de session et table d'activité récente.

FORM: Mode Operate, construction code-led (écrans d'app) ; structure de
cartes et de typographie inspirée des captures, identité verte conservée et
rehaussée par l'ambre. seed: none (direction fixée par le brief).

FINISH: unreviewed and undocumented is unfinished; this build ends with the
finish review, the verdict, DESIGN.md, and every shipping raster carrying its
provenance.
