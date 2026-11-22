import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../data/download_platform.dart';
import '../data/download_repository.dart';
import '../data/pack_downloader.dart';
import '../data/pack_store.dart';
import '../data/pack_store_factory.dart';
import '../domain/download_exception.dart';
import '../domain/installed_pack.dart';

final packStoreProvider = Provider<PackStore>((ref) => createPackStore());

final downloadRepositoryProvider = Provider<DownloadRepository>(
  (ref) => DownloadRepository(store: ref.watch(packStoreProvider)),
);

final downloadHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final packDownloaderProvider = Provider<PackDownloader>((ref) {
  final downloader = PackDownloader(
    store: ref.watch(packStoreProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
    client: ref.watch(downloadHttpClientProvider),
  );
  ref.onDispose(downloader.dispose);
  return downloader;
});

final downloadIndexProvider =
    AsyncNotifierProvider<DownloadIndexNotifier, DownloadIndex>(
      DownloadIndexNotifier.new,
    );

class DownloadIndexNotifier extends AsyncNotifier<DownloadIndex> {
  @override
  Future<DownloadIndex> build() async {
    if (ref.watch(downloadPlatformProvider) != DownloadPlatform.mobile) {
      return DownloadIndex.empty();
    }
    try {
      return await ref.watch(downloadRepositoryProvider).reconcile();
    } catch (_) {
      return DownloadIndex.empty();
    }
  }

  Future<void> refresh() async {
    if (ref.read(downloadPlatformProvider) != DownloadPlatform.mobile) return;
    try {
      state = AsyncData(await ref.read(downloadRepositoryProvider).reconcile());
    } catch (_) {
      state = AsyncData(DownloadIndex.empty());
    }
  }
}

final installedPackProvider = Provider.family<InstalledPack?, String>((
  ref,
  bookId,
) {
  return ref.watch(downloadIndexProvider).value?[bookId];
});

final downloadJobsProvider =
    NotifierProvider<DownloadJobsNotifier, Map<String, DownloadJob>>(
      DownloadJobsNotifier.new,
    );

class DownloadJobsNotifier extends Notifier<Map<String, DownloadJob>> {
  final Map<String, DownloadCancelToken> _tokens = {};

  @override
  Map<String, DownloadJob> build() => const {};

  Future<void> start(String bookId) async {
    if (ref.read(downloadPlatformProvider) != DownloadPlatform.mobile) return;
    if (state.values.any((job) => job.isActive)) return;
    if (_tokens.containsKey(bookId)) return;

    final token = DownloadCancelToken();
    _tokens[bookId] = token;
    _set(DownloadJob.starting(bookId, 0));
    try {
      final installed = await ref
          .read(packDownloaderProvider)
          .download(
            bookId: bookId,
            cancelToken: token,
            onProgress: (completed, total) {
              if (_tokens[bookId] != token) return;
              final current = state[bookId];
              _set(
                DownloadJob(
                  bookId: bookId,
                  status: current?.status == DownloadJobStatus.cancelling
                      ? DownloadJobStatus.cancelling
                      : DownloadJobStatus.downloading,
                  bytesDownloaded: completed,
                  totalBytes: total,
                ),
              );
            },
          );
      await ref.read(downloadRepositoryProvider).recordInstalled(installed);
      _tokens.remove(bookId);
      _remove(bookId);
      await ref.read(downloadIndexProvider.notifier).refresh();
    } on DownloadCancelledException {
      _tokens.remove(bookId);
      _set(
        DownloadJob(
          bookId: bookId,
          status: DownloadJobStatus.error,
          bytesDownloaded: 0,
          totalBytes: 0,
          error: 'Téléchargement annulé.',
        ),
      );
    } catch (error) {
      _tokens.remove(bookId);
      _set(
        DownloadJob(
          bookId: bookId,
          status: DownloadJobStatus.error,
          bytesDownloaded: 0,
          totalBytes: 0,
          error: downloadErrorMessage(error),
        ),
      );
    }
  }

  void cancel(String bookId) {
    final token = _tokens[bookId];
    if (token == null) return;
    token.cancel();
    final current = state[bookId];
    if (current != null) {
      _set(
        current.copyWith(
          status: DownloadJobStatus.cancelling,
          clearError: true,
        ),
      );
    }
  }

  void clearError(String bookId) {
    final current = state[bookId];
    if (current == null || current.status != DownloadJobStatus.error) return;
    _remove(bookId);
  }

  void _set(DownloadJob job) {
    state = Map.unmodifiable({...state, job.bookId: job});
  }

  void _remove(String bookId) {
    state = Map.unmodifiable({...state}..remove(bookId));
  }
}

final downloadJobProvider = Provider.family<DownloadJob?, String>((
  ref,
  bookId,
) {
  return ref.watch(downloadJobsProvider)[bookId];
});
