# Phase 14 — Exigences : Back-office contenu

## Authentification admin

- **FR-14.1** — Le back-office est actif uniquement si `STORYLINGO_ADMIN_TOKEN`
  est défini ; sinon toutes les routes `/admin` répondent 404.
- **FR-14.2** — Le mot de passe admin est comparé en temps constant au token
  configuré ; un échec ne pose aucun cookie et ne révèle pas le token attendu.
- **FR-14.3** — Une connexion réussie pose un cookie de session signé (JWT
  HS256), `HttpOnly`, `SameSite=Lax`, `Secure` hors HTTP local, valable 12 h.
- **FR-14.4** — La clé de signature provient de
  `STORYLINGO_ADMIN_SESSION_SECRET` ; à défaut, une clé éphémère par processus
  est utilisée (les sessions expirent au redémarrage).
- **FR-14.5** — Toute page `/admin` hors connexion redirige (303) vers
  `/admin/login` ; toute action POST exige un jeton CSRF de session (sinon 403).
- **FR-14.6** — Le token admin, la clé de session et les cookies ne sont jamais
  rendus dans les pages, réponses ou logs.

## Liste des livres

- **FR-14.7** — `/admin/books` authentifié affiche pour chaque livre : id, titre,
  titre français, niveau, version de pack, nombre de chapitres, statut
  gratuit/payant et date de mise à jour.
- **FR-14.8** — Les valeurs issues des manifestes sont échappées (pas d'injection
  HTML/XSS).
- **FR-14.9** — La déconnexion efface le cookie et renvoie vers la connexion.

## Import de pack

- **FR-14.10** — `/admin/import` accepte un fichier ZIP contenant `manifest.json`
  à la racine ou dans un unique dossier racine, et le publie via
  `publish_pack` (validation complète, backup atomique).
- **FR-14.11** — L'extraction refuse les chemins absolus, `..`, les liens
  symboliques et les entrées non régulières (anti zip-slip).
- **FR-14.12** — La taille de l'archive est limitée
  (`STORYLINGO_ADMIN_MAX_UPLOAD_MB`, 200 Mo par défaut) ; un dépassement répond
  413 sans rien publier.
- **FR-14.13** — Le formulaire propose « conserver », « gratuit » ou « payant » ;
  « conserver » préserve le statut d'un livre existant et rend un nouveau livre
  payant.
- **FR-14.14** — Un ZIP invalide, un manifeste invalide ou un pack incomplet
  affiche un message dans le formulaire (400) sans trace serveur inattendue.
- **FR-14.15** — Après succès, l'utilisateur revient à la liste avec un message
  de confirmation.

## Bascule gratuit/payant

- **FR-14.16** — `/admin/books/{id}/access` met à jour `books.is_free` et
  `updated_at`, avec confirmation explicite dans l'interface.
- **FR-14.17** — Le changement est immédiatement visible dans `/v1/catalogue`,
  `/v1/books/{id}` et le manifeste téléchargé (`isFree`), la base restant
  l'autorité.
- **FR-14.18** — Un identifiant inconnu répond 404 ; une valeur d'accès invalide
  répond 400.

## Audit et limites

- **SEC-14.1** — Aucun secret dans le dépôt : token et clé de session uniquement
  via variables d'environnement, jamais loggés.
- **SEC-14.2** — Les actions sensibles (import, bascule) sont journalisées en
  logs structurés (livre, accès) sans donnée d'authentification.
- **SEC-14.3** — L'import écrit dans un répertoire temporaire système nettoyé en
  fin de requête ; `server/data` n'est jamais touché par les tests.
- **SEC-14.4** — Les routes publiques, le CORS local et l'authentification
  applicative restent inchangés.

## Hors périmètre

- Suppression de livre, édition des métadonnées, gestion RevenueCat, comptes
  admin multiples, import EPUB depuis le navigateur, table d'audit en base.
