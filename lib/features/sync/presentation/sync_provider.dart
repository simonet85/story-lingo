import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../../core/prefs/user_prefs_provider.dart';
import '../../account/presentation/auth_provider.dart';
import '../../program/presentation/program_provider.dart';
import '../../reading/presentation/reading_progress_provider.dart';
import '../../vocabulary/presentation/saved_words_provider.dart';
import '../../vocabulary/presentation/srs_provider.dart';
import '../data/sync_api.dart';
import '../data/sync_local_store.dart';
import '../domain/sync_record.dart';

final syncApiProvider = Provider<SyncApi>((ref) {
  return SyncApi(baseUrl: ref.watch(apiBaseUrlProvider));
});

final syncLocalStoreProvider = Provider<SyncLocalStore>((ref) {
  final prefs = ref.watch(prefsRepositoryProvider);
  return SyncLocalStore(
    preferences: prefs.preferences,
    prefs: prefs,
    reading: ref.watch(readingProgressRepositoryProvider),
    words: ref.watch(savedWordsRepositoryProvider),
    srs: ref.watch(srsRepositoryProvider),
    program: ref.watch(programRepositoryProvider),
  );
});

enum SyncStatus { idle, syncing, success, failure }

class SyncState {
  const SyncState({
    required this.status,
    this.lastSyncedAt,
    this.error,
  });

  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? error;

  bool get isBusy => status == SyncStatus.syncing;

  bool get hasError => status == SyncStatus.failure && error != null;
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

class SyncController extends Notifier<SyncState> {
  @override
  SyncState build() {
    return SyncState(
      status: SyncStatus.idle,
      lastSyncedAt: ref.watch(prefsRepositoryProvider).loadLastSyncAt(),
    );
  }

  Future<bool> syncNow({bool silent = false}) async {
    if (state.isBusy) return false;
    final auth = ref.read(authControllerProvider);
    if (!auth.isSignedIn) {
      if (!silent) {
        state = SyncState(
          status: SyncStatus.failure,
          lastSyncedAt: state.lastSyncedAt,
          error: 'Connectez-vous pour synchroniser.',
        );
      }
      return false;
    }

    state = SyncState(
      status: SyncStatus.syncing,
      lastSyncedAt: state.lastSyncedAt,
    );
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .ensureSession();
      if (session == null) {
        state = SyncState(
          status: SyncStatus.failure,
          lastSyncedAt: state.lastSyncedAt,
          error: 'Session expirée. Reconnectez-vous.',
        );
        return false;
      }

      final api = ref.read(syncApiProvider);
      final store = ref.read(syncLocalStoreProvider);
      final prefs = ref.read(prefsRepositoryProvider);
      final localRecords = store.collect();

      final pushed = await api.push(
        token: session.accessToken,
        records: localRecords,
      );
      final pulled = await api.pull(
        token: session.accessToken,
        since: prefs.loadSyncCursor(),
      );

      final winners = _latestWinners([...pushed.records, ...pulled.records]);
      await store.apply(winners.values.toList());
      await prefs.saveSyncCursor(pulled.revision);
      final now = DateTime.now();
      await prefs.saveLastSyncAt(now);

      _refreshLocalProviders();
      state = SyncState(status: SyncStatus.success, lastSyncedAt: now);
      return true;
    } on SyncException catch (error) {
      if (error.unauthorized) {
        await ref.read(authControllerProvider.notifier).signOut();
      }
      state = SyncState(
        status: SyncStatus.failure,
        lastSyncedAt: state.lastSyncedAt,
        error: error.message,
      );
      return false;
    } on Exception {
      state = SyncState(
        status: SyncStatus.failure,
        lastSyncedAt: state.lastSyncedAt,
        error: 'Synchronisation impossible. Réessayez.',
      );
      return false;
    }
  }

  Map<String, SyncRecord> _latestWinners(List<SyncRecord> records) {
    final winners = <String, SyncRecord>{};
    for (final record in records) {
      final current = winners[record.key];
      if (current == null || record.updatedAt >= current.updatedAt) {
        winners[record.key] = record;
      }
    }
    return winners;
  }

  void _refreshLocalProviders() {
    ref.invalidate(savedWordsProvider);
    ref.invalidate(srsProvider);
    ref.invalidate(programProvider);
    ref.invalidate(userPrefsProvider);
    ref.invalidate(readingProgressProvider);
  }
}
