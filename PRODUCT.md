# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Francophones de 16 à 45 ans, niveau d'anglais A2 à B2, motivés mais avec
très peu de temps disponible. Ils aiment les histoires et préfèrent
l'immersion aux exercices scolaires. Ils utilisent l'application sur Android
et iOS au quotidien ; le web sert de grand écran de consultation et de
lecture.

## Product Purpose

Storylingo permet d'améliorer son anglais en 28 jours avec des livres
adaptés. Chaque session combine trois gestes — lire, écouter, réviser — en
7 à 10 minutes par jour. Le succès : au bout de 28 jours, l'utilisateur a
terminé son premier livre, repris confiance à l'oral et pris l'habitude de
lire en anglais sans avoir eu l'impression de travailler.

## Positioning

L'anglais s'apprend par l'histoire, pas par l'exercice : vocabulaire rencontré
dans une intrigue, texte et audio natifs synchronisés au mot près, et un
parcours guidé de 28 jours avec un seul objectif quotidien. Ni cours de
grammaire, ni dictionnaire, ni jeu d'exercices.

## Operating Context

Sessions courtes, souvent le soir ou dans les transports ; usage hors-ligne
de première classe ; appareils modestes. Le programme 28 jours impose un
chapitre et une révision de vocabulaire par jour. L'application est
offline-first : progression, positions de lecture et SRS vivent localement et
se synchronisent quand le réseau le permet. Le web (tableau de bord) reprend
les mêmes données, sans paiement mobile money ni téléchargements natifs.

## Capabilities and Constraints

- Onboarding par niveau et centres d'intérêt ; catalogue de classiques
  adaptés par niveau (Sleepy Hollow, Sherlock Holmes, Dracula, Alice…).
- Lecteur immersif : modes Lire / Écouter / Lire + Écouter, vitesse
  0.8x–1.5x, surlignage karaoké, dictionnaire au tap.
- Vocabulaire : détection selon le niveau, flashcards, répétition espacée
  locale.
- Parcours 28 jours, streak protégé, statistiques, badges, rappels doux.
- Hors-ligne complet, thèmes clair et sombre, comptes et synchronisation.
- Freemium : 1 à 2 livres gratuits ; Premium mensuel/annuel via RevenueCat ;
  paiement mobile money via backend (flag désactivé par défaut, masqué sur
  le web).
- La session cœur ne dépasse jamais 10 minutes ; un seul objectif par jour ;
  la lecture ne dépend jamais du réseau.
- Aucune donnée personnelle dans les événements analytics ; consentement
  opt-in, identité pseudonyme.
- Package `money_fusion` (dépôt séparé) : jamais de lien API MoneyFusion ni de
  clé PAYOUT côté client.

## Brand Commitments

- Nom : Storylingo. Promesse : « Améliore ton anglais en 28 jours avec des
  livres adaptés. »
- Ton positif, jamais punitif : une journée manquée ne casse pas l'élan.
- Vert Storylingo (`#2F5D50`) conservé comme couleur primaire dans la refonte
  visuelle hybride ; accent secondaire ambre ; corail réservé aux erreurs.
- Aucune image ni marque tierce reprise des captures d'inspiration
  (ReadStream, BookTok, BookScope).

## Evidence on Hand

- Captures d'inspiration dans `docs/` (mobile, web, dashboard), versionnées
  comme cible visuelle de la phase 16a.
- Spécifications complètes dans `specs/` (phases 1 à 16a), mission et
  tech-stack.
- Application fonctionnelle : onboarding, lecture, audio, SRS, programme,
  comptes, hors-ligne, paywall, mobile money.
- Aucun témoignage, client, benchmark ou revenu réel : ne pas en inventer.

## Product Principles

1. L'immersion d'abord : on lit une histoire, on ne fait pas des exercices.
2. La contrainte libère : un seul objectif, 10 minutes, streak protégé.
3. La lecture ne dépend jamais du réseau.
4. Le feedback encourage, jamais il ne culpabilise.
5. Chaque écran sert le prochain geste : lire, écouter ou réviser.

## Accessibility & Inclusion

- Cibles tactiles ≥ 48 dp, contrastes AA, texte à 200 % sans perte d'action.
- Audit a11y complet prévu en phase 16, sur le design livré en 16a.
- Public non natif de l'anglais : hiérarchie claire, libellés explicites,
  pas de dépendance à la couleur seule.
