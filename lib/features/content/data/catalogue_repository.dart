import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/book_manifest.dart';
import '../domain/catalogue.dart';
import '../domain/chapter.dart';
import '../domain/content_format_exception.dart';

class CatalogueException implements Exception {
  const CatalogueException(this.message);

  final String message;

  @override
  String toString() => 'CatalogueException: $message';
}

class CatalogueResult {
  const CatalogueResult({
    required this.catalogue,
    required this.fromCache,
    required this.stale,
  });

  final Catalogue catalogue;
  final bool fromCache;
  final bool stale;
}

class CatalogueRepository {
  CatalogueRepository({
    required String baseUrl,
    required this.preferences,
    http.Client? client,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 3),
    this.cacheTtl = const Duration(hours: 12),
  }) : _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
       _client = client ?? http.Client(),
       _now = now ?? DateTime.now;

  static const String cachePrefix = 'content.cache.';
  static const String _catalogueKey = '${cachePrefix}catalogue.v1';

  final String _baseUrl;
  final SharedPreferences preferences;
  final http.Client _client;
  final DateTime Function() _now;
  final Duration timeout;
  final Duration cacheTtl;

  String get baseUrl => _baseUrl;

  void dispose() => _client.close();

  Future<CatalogueResult> loadCatalogue({bool forceRefresh = false}) async {
    final cache = _readCachedCatalogue();
    final cachedCatalogue = cache?.catalogue;

    if (!forceRefresh && cache != null && _isFresh(cache.fetchedAt)) {
      return CatalogueResult(
        catalogue: cache.catalogue,
        fromCache: true,
        stale: false,
      );
    }

    final headers = <String, String>{'Accept': 'application/json'};
    if (cachedCatalogue != null && cache?.etag != null) {
      headers['If-None-Match'] = cache!.etag!;
    }

    try {
      final response = await _request('/v1/catalogue', headers: headers);
      if (response.statusCode == 304 &&
          cachedCatalogue != null &&
          cache != null) {
        await _writeCache(
          _catalogueKey,
          cache.payload,
          etag: response.headers['etag'] ?? cache.etag,
        );
        return CatalogueResult(
          catalogue: cachedCatalogue,
          fromCache: true,
          stale: false,
        );
      }
      if (response.statusCode != 200) {
        throw CatalogueException('HTTP ${response.statusCode} on /v1/catalogue.');
      }
      final payload = _decodeObject(response);
      final catalogue = Catalogue.fromJson(payload);
      await _writeCache(_catalogueKey, payload, etag: response.headers['etag']);
      return CatalogueResult(
        catalogue: catalogue,
        fromCache: false,
        stale: false,
      );
    } catch (error) {
      if (cachedCatalogue != null) {
        return CatalogueResult(
          catalogue: cachedCatalogue,
          fromCache: true,
          stale: true,
        );
      }
      if (error is CatalogueException) rethrow;
      throw CatalogueException('Catalogue unavailable: $error');
    }
  }

  Future<BookManifest> loadManifest(String bookId) async {
    final key = '${cachePrefix}manifest.$bookId.v1';
    final cached = _readCachedManifest(key, bookId);
    if (cached != null && _isFresh(cached.fetchedAt)) return cached.manifest;

    try {
      final path = '/v1/books/${Uri.encodeComponent(bookId)}';
      final payload = await _getJson(path);
      final manifest = BookManifest.fromJson(payload);
      if (manifest.id != bookId) {
        throw ContentFormatException(
          'Manifest id "${manifest.id}" does not match "$bookId".',
        );
      }
      await _writeCache(key, payload);
      return manifest;
    } catch (_) {
      if (cached != null) return cached.manifest;
      rethrow;
    }
  }

  Future<Chapter> loadChapter({
    required String bookId,
    required BookChapterSummary summary,
  }) async {
    final url = summary.url;
    if (url == null) {
      throw ContentFormatException(
        'Chapter "${summary.id}" has no remote URL.',
      );
    }
    final key = '${cachePrefix}chapter.$bookId.${summary.id}.v1';
    final cached = _readCachedChapter(key, bookId, summary);
    if (cached != null && _isFresh(cached.fetchedAt)) return cached.chapter;

    try {
      final payload = await _getJson(url);
      final chapter = _parseChapter(payload, bookId, summary);
      await _writeCache(key, payload);
      return chapter;
    } catch (_) {
      if (cached != null) return cached.chapter;
      rethrow;
    }
  }

  Uri resolve(String location) {
    final uri = Uri.parse(location);
    if (uri.hasScheme) return uri;
    final path = location.startsWith('/') ? location : '/$location';
    return Uri.parse('$_baseUrl$path');
  }

  Future<http.Response> _request(
    String path, {
    Map<String, String>? headers,
  }) {
    return _client
        .get(Uri.parse('$_baseUrl$path'), headers: headers)
        .timeout(timeout);
  }

  Future<Map<String, dynamic>> _getJson(String pathOrUrl) async {
    final path = pathOrUrl.startsWith('/') || Uri.parse(pathOrUrl).hasScheme
        ? pathOrUrl
        : '/$pathOrUrl';
    final uri = Uri.parse(path).hasScheme
        ? Uri.parse(path)
        : Uri.parse('$_baseUrl$path');
    // Transport failures (airplane mode, DNS, timeouts) must surface as
    // CatalogueException so callers can map them to the offline message.
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
    } catch (error) {
      throw CatalogueException('Network error on $pathOrUrl: $error');
    }
    if (response.statusCode != 200) {
      throw CatalogueException('HTTP ${response.statusCode} on $pathOrUrl.');
    }
    return _decodeObject(response);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw CatalogueException('Invalid JSON: ${error.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const CatalogueException('Expected a JSON object.');
    }
    return decoded;
  }

  Chapter _parseChapter(
    Map<String, dynamic> payload,
    String bookId,
    BookChapterSummary summary,
  ) {
    final audio = payload['audio'];
    final prepared = Map<String, dynamic>.of(payload);
    if (audio is Map<String, dynamic>) {
      final rawUrl = audio['url'];
      if (rawUrl is String) {
        prepared['audio'] = <String, dynamic>{
          ...audio,
          'url': resolve(rawUrl).toString(),
        };
      }
    }
    final chapter = Chapter.fromJson(prepared);
    if (chapter.bookId != bookId) {
      throw ContentFormatException(
        'Chapter "${chapter.id}" belongs to "${chapter.bookId}", '
        'not "$bookId".',
      );
    }
    if (chapter.id != summary.id || chapter.number != summary.number) {
      throw ContentFormatException(
        'Chapter "${chapter.id}" does not match manifest entry '
        '"${summary.id}" (number ${summary.number}).',
      );
    }
    return chapter;
  }

  bool _isFresh(DateTime fetchedAt) =>
      _now().difference(fetchedAt) < cacheTtl;

  _CachedCatalogue? _readCachedCatalogue() {
    final entry = _readCache(_catalogueKey);
    if (entry == null) return null;
    try {
      final catalogue = Catalogue.fromJson(entry.payload);
      return _CachedCatalogue(
        catalogue: catalogue,
        payload: entry.payload,
        fetchedAt: entry.fetchedAt,
        etag: entry.etag,
      );
    } catch (_) {
      return null;
    }
  }

  _CachedManifest? _readCachedManifest(String key, String bookId) {
    final entry = _readCache(key);
    if (entry == null) return null;
    try {
      final manifest = BookManifest.fromJson(entry.payload);
      if (manifest.id != bookId) return null;
      return _CachedManifest(manifest: manifest, fetchedAt: entry.fetchedAt);
    } catch (_) {
      return null;
    }
  }

  _CachedChapter? _readCachedChapter(
    String key,
    String bookId,
    BookChapterSummary summary,
  ) {
    final entry = _readCache(key);
    if (entry == null) return null;
    try {
      final chapter = _parseChapter(entry.payload, bookId, summary);
      return _CachedChapter(chapter: chapter, fetchedAt: entry.fetchedAt);
    } catch (_) {
      return null;
    }
  }

  _CacheEntry? _readCache(String key) {
    final raw = preferences.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final fetchedAt = decoded['fetchedAt'];
      final payload = decoded['payload'];
      if (fetchedAt is! int || payload is! Map<String, dynamic>) return null;
      final etag = decoded['etag'];
      return _CacheEntry(
        payload: payload,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(fetchedAt),
        etag: etag is String ? etag : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(
    String key,
    Map<String, dynamic> payload, {
    String? etag,
  }) async {
    try {
      await preferences.setString(
        key,
        jsonEncode({
          'fetchedAt': _now().millisecondsSinceEpoch,
          'etag': etag,
          'payload': payload,
        }),
      );
    } catch (_) {
      // A cache write failure must never break content loading.
    }
  }
}

class _CacheEntry {
  const _CacheEntry({
    required this.payload,
    required this.fetchedAt,
    required this.etag,
  });

  final Map<String, dynamic> payload;
  final DateTime fetchedAt;
  final String? etag;
}

class _CachedCatalogue {
  const _CachedCatalogue({
    required this.catalogue,
    required this.payload,
    required this.fetchedAt,
    required this.etag,
  });

  final Catalogue catalogue;
  final Map<String, dynamic> payload;
  final DateTime fetchedAt;
  final String? etag;
}

class _CachedManifest {
  const _CachedManifest({required this.manifest, required this.fetchedAt});

  final BookManifest manifest;
  final DateTime fetchedAt;
}

class _CachedChapter {
  const _CachedChapter({required this.chapter, required this.fetchedAt});

  final Chapter chapter;
  final DateTime fetchedAt;
}
