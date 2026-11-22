import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/saved_words_repository.dart';
import '../domain/word_entry.dart';

final savedWordsRepositoryProvider = Provider<SavedWordsRepository>(
  (ref) => throw UnimplementedError(
    'savedWordsRepositoryProvider must be overridden at app start',
  ),
);

final savedWordsProvider =
    NotifierProvider<SavedWordsController, List<SavedWord>>(
      SavedWordsController.new,
    );

class SavedWordsController extends Notifier<List<SavedWord>> {
  @override
  List<SavedWord> build() => ref.watch(savedWordsRepositoryProvider).load();

  bool contains(String id) => state.any((saved) => saved.entry.id == id);

  /// Returns `true` when the word was added, `false` when it was removed.
  Future<bool> toggle(WordEntry entry) async {
    final exists = contains(entry.id);
    final repository = ref.read(savedWordsRepositoryProvider);
    if (exists) {
      await repository.markDeleted(entry.id, DateTime.now());
    } else {
      await repository.clearTombstone(entry.id);
    }
    final next = exists
        ? state.where((saved) => saved.entry.id != entry.id).toList()
        : [...state, SavedWord(entry: entry, savedAt: DateTime.now())];
    await _persist(next);
    return !exists;
  }

  Future<void> remove(String id) async {
    if (!contains(id)) return;
    await ref
        .read(savedWordsRepositoryProvider)
        .markDeleted(id, DateTime.now());
    await _persist(state.where((saved) => saved.entry.id != id).toList());
  }

  Future<void> _persist(List<SavedWord> next) async {
    await ref.read(savedWordsRepositoryProvider).save(next);
    state = List.unmodifiable(next);
  }
}
