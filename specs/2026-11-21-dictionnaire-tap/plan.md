# Phase 6 Plan — Dictionnaire au tap

Objectif : pendant la lecture, toucher un mot clé ouvre une fiche (phonétique, nature, traduction, définition, exemple) avec sa prononciation, et permet de l'ajouter à « Ma liste de mots ». Tout fonctionne hors-ligne, sans nouvelle donnée de contenu.

## A. Contrat et données locales

1. Ne pas modifier le format du pack : les mots annotés (`vocabulary` + `vocabId` par segment) fournissent déjà tous les champs de la fiche. Aucun bump de `packVersion` ni de `prefs.version`.
2. Ajouter `WordEntry` (`id`, `word`, `partOfSpeech`, `phonetic`, `definitionEn`, `translationFr`, `example`, `bookId`, `chapterId`, clip optionnel) et `PronunciationClip` (`asset`, `start`, `end`) dans `features/vocabulary/domain/`.
3. Identité de fiche : `${bookId}/${vocabId}` (stable entre chapitres et livres).
4. `SavedWord` = instantané de `WordEntry` + `savedAt`, sérialisable en JSON tolérant (les entrées corrompues sont ignorées au chargement).
5. Ajouter la clé additive `words.saved` (`List<String>` de JSON) et `SavedWordsRepository` au-dessus de `SharedPreferences`.
6. Exposer `savedWordsProvider` (`NotifierProvider<List<SavedWord>>`) : chargement synchrone, `toggle(entry)` idempotent, `remove(id)`, état réactif.

## B. Mapping mot → fiche

7. `dictionaryEntryFor(Chapter, ChapterWord)` retourne `null` pour un token non annoté et une fiche complète pour un token annoté.
8. Pour « Sleepy Hollow » (deux tokens sous le même `vocabId`), calculer la tranche audio du groupe contigu de tokens partageant le `vocabId` dans le paragraphe : `start` du premier token, `end` du dernier.
9. Sans audio (chapitre v1) ou sans timing, la fiche existe avec `clip = null` (repli TTS à la prononciation).

## C. Prononciation

10. Définir `WordPronouncer` (`pronounce(word, clip)`, `stop()`) avec deux collaborateurs injectables : lecteur de tranche pack et synthèse vocale.
11. Lecteur pack : `AudioPlayer` dédié, `setAsset` → `seek(clip.start)` → `play`, arrêt par minuterie à `clip.end - clip.start` (150 ms de marge), `stop()` à chaque nouvel appel et à la fermeture de la fiche.
12. Repli : si `clip == null` ou si la lecture de la tranche échoue, synthèse `flutter_tts` en `en-US` du mot affiché (pas du token).
13. Toute défaillance des deux voies remonte une exception gérée par la fiche (« Prononciation indisponible. » sous les actions) — jamais de crash.
14. Ajouter `flutter_tts` et la déclaration `<queries><intent android:name="android.intent.action.TTS_SERVICE"/>` au manifeste Android.
15. Factory Riverpod surchargeable (`wordPronouncerProvider`) pour les tests ; aucun plugin créé tant que la fiche n'est pas ouverte.

## D. Interaction et UI

16. Rendre cliquables uniquement les tokens annotés : `ChapterParagraphText` devient `StatefulWidget`, cache un `TapGestureRecognizer` par index de mot annoté et les libère au changement de layout/au `dispose` (aucune fuite pendant les rebuilds karaoké).
17. Taper un mot annoté met la narration en pause (modes audio), puis ouvre une feuille modale (`showModalBottomSheet`, `isScrollControlled`, `useSafeArea`, poignée visible).
18. Fiche : mot, phonétique, nature traduite (nom, verbe, adjectif, nom propre…), traduction FR mise en avant, définition EN, exemple encadré, bouton « Écouter », bouton d'ajout/retrait, lien « Voir ma liste de mots ».
19. Retour visuel **dans la fiche** (visible au-dessus de la feuille) : « Ajouté à votre liste de mots. » / « Retiré de votre liste de mots. », bouton d'état « Dans ma liste de mots » avec coche ; snackbar uniquement pour le retrait depuis l'écran de liste.
20. Mettre à jour l'aide du lecteur : « Touchez un mot surligné pour voir sa définition et l’ajouter à votre liste. »
21. Écran « Ma liste de mots » sur la route `/words` : état vide engageant, compteur, cartes (mot, phonétique, traduction), ouverture de la fiche au tap, retrait explicite.
22. Accès à la liste : action avec badge dans la barre du lecteur, action dans `StorylingoAppBar` (Aujourd'hui / Bibliothèque / Progrès) et lien depuis la fiche.
23. Mettre en pause la prononciation à la fermeture de la fiche ; ne pas relancer automatiquement la narration.

## E. Tests et validation

24. Tests unitaires mapping : token non annoté, fiche complète, clip du token, clip du groupe « Sleepy Hollow », chapitre sans audio.
25. Tests unitaires stockage : aller-retour JSON + clip, tolérance aux entrées invalides, déduplication, ordre, `toggle` add/remove, persistance entre deux repositories.
26. Tests unitaires prononciation : clip prioritaire, TTS si clip absent, TTS si le lecteur pack échoue, exception si les deux échouent, `stop` propage.
27. Tests widget : fiche ouverte par le recognizer d'un mot annoté, champs affichés, prononciation appelée avec clip, ajout/retrait persistés, liste accessible et vide/pleine, suppression, pause de la narration, absence de recognizer sur les mots non annotés, 360 px sans overflow, non-régression des tests existants.
28. `flutter analyze` + `flutter test` verts ; captures web clair/sombre de la fiche, de la liste et de l'état vide via CDP.
29. Validation Android sur `storylingo_api36` : tap réel, feuille, tranche audio du mot, ajout, liste, retrait, persistance après redémarrage, mode avion ; captures archivées.
30. Mettre à jour `README.md` avec le lien vers cette spec.
