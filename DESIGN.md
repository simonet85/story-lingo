---
name: Storylingo
description: Une bibliothèque chaleureuse et éditoriale pour apprendre l'anglais par la lecture.
colors:
  primary-forest: "#2F5D50"
  cream-paper: "#F7F1E6"
  card-cream: "#FFFCF5"
  ink: "#1B1F1D"
  ink-surface: "#101614"
  card-ink: "#161D1A"
  amber-accent: "#E4A23C"
  amber-deep: "#8A5A16"
  amber-light: "#E9B45F"
  sage-mist: "#D7E6DD"
  error-clay: "#B3261E"
typography:
  display:
    fontFamily: "Roboto, system-ui, sans-serif"
    fontSize: "36px"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-0.5px"
  headline:
    fontFamily: "Roboto, system-ui, sans-serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.25
    letterSpacing: "-0.1px"
  title:
    fontFamily: "Roboto, system-ui, sans-serif"
    fontSize: "20px"
    fontWeight: 700
    lineHeight: 1.3
  body:
    fontFamily: "Roboto, system-ui, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.55
  label:
    fontFamily: "Roboto, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 600
    lineHeight: 1.35
    letterSpacing: "0.2px"
rounded:
  card: "20px"
  card-large: "24px"
  button: "14px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
  xxl: "48px"
components:
  button-primary:
    backgroundColor: "{colors.primary-forest}"
    textColor: "#FFFFFF"
    rounded: "{rounded.button}"
    height: "52px"
    padding: "0 24px"
  card:
    backgroundColor: "{colors.card-cream}"
    textColor: "{colors.ink}"
    rounded: "{rounded.card}"
    padding: "16px"
  chip-selected:
    backgroundColor: "{colors.sage-mist}"
    textColor: "#10251F"
    rounded: "{rounded.pill}"
    padding: "4px 8px"
  field:
    backgroundColor: "#FBF6EC"
    textColor: "{colors.ink}"
    rounded: "{rounded.button}"
    padding: "14px 16px"
---

# Design System: Storylingo

## Overview

**Creative North Star: "La salle de lecture"**

Storylingo ressemble à une salle de lecture chaleureuse : papier crème,
bois vert profond, lumière ambrée. L'histoire et le geste du jour passent
avant les tableaux de bord décoratifs ; aucun chiffre n'est affiché s'il
n'est pas réel. Le système est volontairement plat et typographique —
grandes cartes crème cernées d'un filet fin, titres affirmés, couvertures
typographiques — pour laisser respirer le texte anglais.

L'ambition est celle d'un mode Operate : l'utilisateur vient lire, écouter
et réviser en moins de dix minutes, pas contempler une interface. Le vert
Storylingo reste la voix d'action ; l'ambre ne réchauffe que les moments
de récompense (série, mode démo, mises en avant douces).

**Key Characteristics:**
- Palette papier crème + encre, vert forêt en primaire, ambre en accent.
- Cartes plates à grand rayon, bordure 1 px, aucune ombre portée.
- Hiérarchie typographique forte (700 pour les titres, 400 pour le corps).
- Trois dispositions : barre basse, rail, barre latérale.
- Aucune image de marque tierce ; illustrations et couvertures originales.

## Colors

La palette tient sur deux pages : une page crème le jour, une page encre la
nuit, avec le même vocabulaire de verts et d'ambres.

### Primary
- **Vert Storylingo** (#2F5D50) : couleur primaire, boutons remplis,
  sélections, liens, barres de progression. En mode sombre, c'est le sage
  clair #9CC9B8 qui porte l'action sur fond encre.
- **Sauge brumeuse** (#D7E6DD / conteneur sombre #2A4A3E) : conteneur
  primaire des états sélectionnés (puces, pastilles, indicateurs de
  navigation).

### Secondary
- **Ambre chaud** (#E4A23C) et **ambre profond** (#8A5A16) : accents de
  récompense — série, badges, encart « mode démo ». Jamais pour une action
  principale.
- **Ambre conteneur** (#F6E3C2 clair, #54401D sombre) : fonds des états
  « à réviser » et des chips secondaires.

### Neutral
- **Papier crème** (#F7F1E6) : fond d'écran clair.
- **Carte crème** (#FFFCF5) : surface des cartes le jour.
- **Encre** (#1B1F1D) : texte principal clair ; **encre de nuit**
  (#101614) et **carte de nuit** (#161D1A) en sombre.
- **Encre atténuée** (#4E5249 / #BFC6BB) : texte secondaire ; contraste AA
  vérifié par test (7,11:1 clair, 10,47:1 sombre minimum).
- **Filet** (#D9CFBC / #3B463F) : bordures et séparateurs à 1 px.

### Named Rules
**La règle du vert unique.** Le vert primaire ne sert qu'à l'action, la
sélection et la progression ; tout le reste vit en neutres et ambre.

## Typography

**Display Font:** Roboto (police système Flutter)
**Body Font:** Roboto

**Caractère :** une seule famille, des graisses franches. Les titres sont
serrés (letter-spacing négatif) et gras ; le corps est généreux (1,55 de
hauteur de ligne) pour la lecture d'anglais.

### Hierarchy
- **Display** (700, 36 px, 1,1) : niveau estimé, grands titres de héros.
- **Headline** (700, 24–32 px, 1,15–1,25) : titres d'écran et de section
  (Aujourd'hui, Réglages, promesse d'accueil).
- **Title** (600–700, 15–20 px, 1,3) : titres de cartes, chapitres,
  libellés de navigation.
- **Body** (400, 14–16 px, 1,5–1,55) : texte courant et descriptions ;
  colonne de lecture plafonnée à 680 px.
- **Label** (600, 11–14 px, 0,1–0,4 px) : métadonnées, puces, badges.

## Layout

Coquille responsive à trois temps : barre de navigation basse sous 720 px,
rail avec libellés de 720 à 960 px, barre latérale de 248 px au-delà de
960 px. Les onglets passent en tableau de bord sur large : Aujourd'hui
range indicateurs, session, mots du jour et activité récente en deux
colonnes ; Bibliothèque adopte une grille ; le lecteur affiche son panneau
latéral.

Largeurs : contenu de flux 560 px, onglets 720 px, colonne de lecture
680 px, tableau de bord 1120 px, progrès 880 px. Rythme spatial sur une
échelle de 4 : 4 / 8 / 16 / 24 / 32 / 48. Marges d'écran 24 px en compact,
32 px en large.

## Elevation & Depth

Aucune ombre. La profondeur vient du ton : cartes plus claires que le fond
(en clair) ou plus sombres (en sombre), bordure `outlineVariant` à 1 px,
rayons généreux. Les états interactifs utilisent les remplissages
`primaryContainer` / `secondaryContainer`, pas d'élévation.

## Shapes

Deux familles : les conteneurs (cartes 20 px, grandes surfaces 24 px) et
les commandes (boutons et champs 14 px, puces et segments en pilule
999 px). Pas de coin carré, pas d'angle coupé ; les couvertures de livres
sont des rectangles typographiques à rayons 20 px.

## Components

### Buttons
- **Shape :** rayon 14 px, hauteur minimale 52 px.
- **Primary :** fond vert, texte blanc, 15 px / 600.
- **Secondary / Ghost :** bordure `outlineVariant`, texte encre ; textes
  d'action en vert.

### Chips
- **Style :** pilule, fond transparent, filet `outlineVariant`.
- **État sélectionné :** fond sauge, texte encre profonde, coche à gauche.

### Cards / Containers
- **Corner Style :** 20 px (24 px pour l'image d'accueil).
- **Background :** carte crème / carte de nuit.
- **Shadow Strategy :** aucune (cf. Elevation & Depth).
- **Border :** 1 px `outlineVariant`.
- **Internal Padding :** 16 px par défaut, 24 px pour les cartes de
  session et de réglages.

### Inputs / Fields
- **Style :** rempli `surfaceContainerLow`, pilule 14 px, filet 1 px.
- **Focus :** bordure verte 1,5 px.
- **Erreur :** bordure corail ; le message reste textuel, pas seulement
  coloré.

### Navigation
- **Style :** libellés sous icônes, indicateur sauge, libellé actif en
  vert gras. Une seule affordance Réglages par largeur (icône d'écran en
  compact, entrée de rail ou de barre latérale au-delà).

### Couvertures de livres
Recomposées en typographie : titre anglais en capitales, fond tiré du
thème via un seed stable, note de lecture à la lettre ajustée pour
qu'aucun mot ne se coupe, icône `auto_stories` discrète en bas à droite.
Aucune image de couverture tierce.

## Do's and Don'ts

### Do:
- **Do** garder le vert primaire pour l'action et la sélection seulement.
- **Do** vérifier chaque paire texte/fond au niveau AA
  (`test/theme_contrast_test.dart`).
- **Do** réserver l'ambre aux récompenses et mises en avant douces.
- **Do** n'afficher que des indicateurs réels, dérivés des providers.
- **Do** conserver les libellés tactiles ≥ 48 dp et les cibles secondaires
  ≥ 44 dp.

### Don't:
- **Don't** ajouter d'ombre portée ni d'élévation Material par défaut.
- **Don't** introduire de données factices (notes, auteurs, social,
  revenus) issues des captures d'inspiration.
- **Don't** utiliser d'image ou de marque tierce.
- **Don't** colorer un état uniquement par la teinte : accompagner la
  couleur d'une icône ou d'un texte.
- **Don't** descendre le corps de texte sous 13 px hors métadonnées.
