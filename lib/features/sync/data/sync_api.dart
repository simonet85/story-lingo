import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/sync_record.dart';

class SyncException implements Exception {
  const SyncException(this.message, {this.unauthorized = false});

  final String message;
  final bool unauthorized;

  @override
  String toString() => message;
}

class PushResult {
  const PushResult({required this.revision, required this.records});

  final int revision;
  final List<SyncRecord> records;
}

class PullResult {
  const PullResult({required this.revision, required this.records});

  final int revision;
  final List<SyncRecord> records;
}

class SyncApi {
  SyncApi({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  String get _root => baseUrl.replaceAll(RegExp(r'/+$'), '');

  Future<PushResult> push({
    required String token,
    required List<SyncRecord> records,
  }) async {
    final response = await _send(
      () => _client.post(
        Uri.parse('$_root/v1/sync/push'),
        headers: _headers(token),
        body: jsonEncode({
          'records': [for (final record in records) record.toJson()],
        }),
      ),
    );
    final body = _decode(response);
    _ensureOk(response, body);
    final revision = body['serverRevision'];
    final rawRecords = body['records'];
    if (revision is! int || rawRecords is! List) {
      throw const SyncException('Réponse de synchronisation invalide.');
    }
    return PushResult(
      revision: revision,
      records: _parseRecords(rawRecords),
    );
  }

  Future<PullResult> pull({
    required String token,
    required int since,
  }) async {
    final uri = Uri.parse('$_root/v1/sync/pull').replace(
      queryParameters: {'since': '$since'},
    );
    final response = await _send(
      () => _client.get(uri, headers: _headers(token)),
    );
    final body = _decode(response);
    _ensureOk(response, body);
    final revision = body['revision'];
    final rawRecords = body['records'];
    if (revision is! int || rawRecords is! List) {
      throw const SyncException('Réponse de synchronisation invalide.');
    }
    return PullResult(
      revision: revision,
      records: _parseRecords(rawRecords),
    );
  }

  List<SyncRecord> _parseRecords(List<dynamic> rawRecords) {
    final records = <SyncRecord>[];
    for (final item in rawRecords) {
      final record = SyncRecord.fromJson(item);
      if (record == null) {
        throw const SyncException('Réponse de synchronisation invalide.');
      }
      records.add(record);
    }
    return records;
  }

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  void _ensureOk(http.Response response, Map<String, dynamic> body) {
    if (response.statusCode == 200) return;
    if (response.statusCode == 401) {
      throw const SyncException(
        'Session expirée. Reconnectez-vous.',
        unauthorized: true,
      );
    }
    final detail = body['detail'];
    throw SyncException(
      detail is String && detail.isNotEmpty
          ? detail
          : 'Synchronisation impossible (${response.statusCode}).',
    );
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const SyncException('Le serveur ne répond pas. Réessayez.');
    } on http.ClientException {
      throw const SyncException(
        'Synchronisation impossible. Vérifiez votre réseau.',
      );
    } on SyncException {
      rethrow;
    } on Exception {
      throw const SyncException(
        'Synchronisation impossible. Vérifiez votre réseau.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    } on FormatException {
      return const {};
    }
    return const {};
  }
}
