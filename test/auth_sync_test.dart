import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/core/prefs/prefs_repository.dart';
import 'package:storylingo/core/prefs/user_prefs_provider.dart';
import 'package:storylingo/features/account/data/auth_api.dart';
import 'package:storylingo/features/account/data/auth_repository.dart';
import 'package:storylingo/features/account/domain/auth_exception.dart';
import 'package:storylingo/features/account/domain/auth_session.dart';
import 'package:storylingo/features/account/presentation/auth_provider.dart';
import 'package:storylingo/features/onboarding/domain/user_level.dart';
import 'package:storylingo/features/program/data/program_repository.dart';
import 'package:storylingo/features/program/domain/program_session.dart';
import 'package:storylingo/features/program/presentation/program_provider.dart';
import 'package:storylingo/features/reading/data/reading_progress_repository.dart';
import 'package:storylingo/features/reading/domain/reading_mode.dart';
import 'package:storylingo/features/reading/presentation/reading_progress_provider.dart';
import 'package:storylingo/features/sync/data/sync_api.dart';
import 'package:storylingo/features/sync/data/sync_local_store.dart';
import 'package:storylingo/features/sync/domain/sync_record.dart';
import 'package:storylingo/features/sync/presentation/sync_provider.dart';
import 'package:storylingo/features/vocabulary/data/saved_words_repository.dart';
import 'package:storylingo/features/vocabulary/data/srs_repository.dart';
import 'package:storylingo/features/vocabulary/domain/srs_card.dart';
import 'package:storylingo/features/vocabulary/domain/word_entry.dart';
import 'package:storylingo/features/vocabulary/presentation/saved_words_provider.dart';
import 'package:storylingo/features/vocabulary/presentation/srs_provider.dart';

import 'support/in_memory_token_store.dart';

AuthSession _session({
  AuthMode mode = AuthMode.dev,
  Duration ttl = const Duration(hours: 1),
  String? refreshToken,
  String accessToken = 'token-1',
}) {
  return AuthSession(
    userId: 'dev_anna',
    email: 'anna@example.com',
    mode: mode,
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: DateTime.now().add(ttl),
  );
}

AuthApi _authApi(MockClient client, {bool supabase = false}) {
  return AuthApi(
    apiBaseUrl: 'http://localhost:8000',
    supabaseUrl: supabase ? 'https://demo.supabase.co' : '',
    supabaseAnonKey: supabase ? 'anon-key' : '',
    client: client,
  );
}

http.Response _ok(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

WordEntry _entry(String word, {String translationFr = 'traduction'}) {
  return WordEntry(
    id: 'sleepy-hollow/$word',
    word: word,
    partOfSpeech: 'noun',
    phonetic: '/$word/',
    definitionEn: 'definition of $word',
    translationFr: translationFr,
    example: 'An example with $word.',
    bookId: 'sleepy-hollow',
    chapterId: 'chapter-01',
  );
}

SrsCard _card(String word) {
  return SrsCard(
    entry: _entry(word),
    card: fsrs.Card(
      cardId: srsCardIdFor('sleepy-hollow/$word'),
      due: DateTime.utc(2026, 11, 22, 8),
    ),
    introducedAt: DateTime.utc(2026, 11, 20, 8),
    reviews: 0,
  );
}

class _Harness {
  _Harness({
    required this.preferences,
    required this.prefs,
    required this.reading,
    required this.words,
    required this.srs,
    required this.program,
    required this.store,
  });

  final SharedPreferences preferences;
  final PrefsRepository prefs;
  final ReadingProgressRepository reading;
  final SavedWordsRepository words;
  final SrsRepository srs;
  final ProgramRepository program;
  final SyncLocalStore store;
}

Future<_Harness> _harness(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final preferences = await SharedPreferences.getInstance();
  final prefs = PrefsRepository(preferences);
  await prefs.ensureSchemaVersion();
  final reading = ReadingProgressRepository(preferences);
  final words = SavedWordsRepository(preferences);
  final srs = SrsRepository(preferences);
  final program = ProgramRepository(preferences);
  return _Harness(
    preferences: preferences,
    prefs: prefs,
    reading: reading,
    words: words,
    srs: srs,
    program: program,
    store: SyncLocalStore(
      preferences: preferences,
      prefs: prefs,
      reading: reading,
      words: words,
      srs: srs,
      program: program,
    ),
  );
}

class _SignedInAuthController extends AuthController {
  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.signedIn,
      session: AuthSession(
        userId: 'dev_anna',
        email: 'anna@example.com',
        mode: AuthMode.dev,
        accessToken: 'token-1',
        expiresAt: DateTime.now().add(const Duration(days: 365)),
      ),
    );
  }
}

class _SignedOutAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.signedOut);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthSession', () {
    test('round-trips through JSON', () {
      final session = _session(
        mode: AuthMode.supabase,
        refreshToken: 'refresh-1',
      );
      final restored = AuthSession.fromJson(
        jsonDecode(jsonEncode(session.toJson())),
      );

      expect(restored, isNotNull);
      expect(restored!.userId, session.userId);
      expect(restored.email, session.email);
      expect(restored.mode, AuthMode.supabase);
      expect(restored.accessToken, session.accessToken);
      expect(restored.refreshToken, 'refresh-1');
      expect(restored.expiresAt, session.expiresAt);
    });

    test('rejects incomplete payloads', () {
      expect(AuthSession.fromJson(null), isNull);
      expect(AuthSession.fromJson({'userId': 'x'}), isNull);
      expect(
        AuthSession.fromJson({
          'userId': 'x',
          'accessToken': 't',
          'mode': 'unknown',
          'expiresAt': DateTime.now().toIso8601String(),
        }),
        isNull,
      );
    });

    test('needsRefresh anticipates expiry within a minute', () {
      final soon = DateTime(2026, 11, 22, 10);
      final almostExpired = AuthSession(
        userId: 'dev_anna',
        email: null,
        mode: AuthMode.dev,
        accessToken: 't',
        expiresAt: soon.add(const Duration(seconds: 30)),
      );
      final fresh = AuthSession(
        userId: 'dev_anna',
        email: null,
        mode: AuthMode.dev,
        accessToken: 't',
        expiresAt: soon.add(const Duration(minutes: 10)),
      );

      expect(almostExpired.needsRefresh(soon), isTrue);
      expect(fresh.needsRefresh(soon), isFalse);
    });

    test('only Supabase sessions with a refresh token can refresh', () {
      expect(_session().canRefresh, isFalse);
      expect(_session(mode: AuthMode.supabase).canRefresh, isFalse);
      expect(
        _session(mode: AuthMode.supabase, refreshToken: 'r').canRefresh,
        isTrue,
      );
    });
  });

  group('AuthApi dev login', () {
    test('parses the dev token and trims the email', () async {
      late Map<String, dynamic> sent;
      final api = _authApi(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/v1/auth/dev/login');
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return _ok({
            'accessToken': 'dev-token',
            'tokenType': 'bearer',
            'expiresIn': 3600,
            'mode': 'dev',
            'user': {'id': 'dev_anna', 'email': 'anna@example.com'},
          });
        }),
      );

      final session = await api.devLogin(' anna@example.com ');

      expect(sent['email'], 'anna@example.com');
      expect(session.mode, AuthMode.dev);
      expect(session.accessToken, 'dev-token');
      expect(session.email, 'anna@example.com');
      expect(session.refreshToken, isNull);
      expect(session.needsRefresh(DateTime.now()), isFalse);
    });

    test('surfaces server validation errors', () async {
      final api = _authApi(
        MockClient(
          (request) async => http.Response(
            jsonEncode({'detail': 'Adresse email invalide.'}),
            422,
          ),
        ),
      );

      await expectLater(
        api.devLogin('nope'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            'Adresse email invalide.',
          ),
        ),
      );
    });

    test('rejects malformed success payloads', () async {
      final api = _authApi(
        MockClient((request) async => _ok({'accessToken': '', 'user': {}})),
      );

      await expectLater(api.devLogin('anna@example.com'), throwsA(isA<AuthException>()));
    });

    test('requires an API base URL', () async {
      final api = AuthApi(
        apiBaseUrl: '',
        supabaseUrl: '',
        supabaseAnonKey: '',
        client: MockClient((request) async => http.Response('{}', 200)),
      );

      await expectLater(
        api.devLogin('anna@example.com'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            contains('API_BASE_URL'),
          ),
        ),
      );
    });
  });

  group('AuthApi Supabase', () {
    test('signs in with the anon key and keeps the refresh token', () async {
      late http.Request captured;
      final api = _authApi(
        MockClient((request) async {
          captured = request;
          return _ok({
            'access_token': 'sb-token',
            'refresh_token': 'sb-refresh',
            'expires_in': 3600,
            'user': {'id': 'user-1', 'email': 'anna@example.com'},
          });
        }),
        supabase: true,
      );

      final session = await api.supabaseSignIn(
        email: ' anna@example.com ',
        password: 'secret',
      );

      expect(captured.url.path, '/auth/v1/token');
      expect(captured.url.queryParameters['grant_type'], 'password');
      expect(captured.headers['apikey'], 'anon-key');
      expect(session.mode, AuthMode.supabase);
      expect(session.refreshToken, 'sb-refresh');
      expect(session.email, 'anna@example.com');
    });

    test('translates invalid credentials', () async {
      final api = _authApi(
        MockClient(
          (request) async => http.Response(
            jsonEncode({'error_description': 'Invalid login credentials'}),
            400,
          ),
        ),
        supabase: true,
      );

      await expectLater(
        api.supabaseSignIn(email: 'anna@example.com', password: 'nope'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            'Identifiants incorrects.',
          ),
        ),
      );
    });

    test('reports email confirmation when sign-up returns no session', () async {
      final api = _authApi(
        MockClient(
          (request) async => _ok({
            'id': 'user-1',
            'email': 'anna@example.com',
          }),
        ),
        supabase: true,
      );

      final outcome = await api.supabaseSignUp(
        email: 'anna@example.com',
        password: 'secret',
      );

      expect(outcome.session, isNull);
      expect(outcome.message, contains('Vérifiez votre email'));
    });

    test('refreshes a Supabase session', () async {
      late Map<String, dynamic> sent;
      final api = _authApi(
        MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return _ok({
            'access_token': 'sb-token-2',
            'refresh_token': 'sb-refresh-2',
            'expires_in': 3600,
            'user': {'id': 'user-1', 'email': 'anna@example.com'},
          });
        }),
        supabase: true,
      );

      final refreshed = await api.refresh(
        _session(mode: AuthMode.supabase, refreshToken: 'sb-refresh'),
      );

      expect(sent['refresh_token'], 'sb-refresh');
      expect(refreshed.accessToken, 'sb-token-2');
      expect(refreshed.refreshToken, 'sb-refresh-2');
    });
  });

  group('AuthRepository', () {
    test('restore returns null without a stored session', () async {
      final store = InMemoryTokenStore();
      final repository = AuthRepository(
        api: _authApi(
          MockClient((request) async => http.Response('{}', 500)),
        ),
        store: store,
      );

      expect(await repository.restore(), isNull);
    });

    test('restore keeps a valid session', () async {
      final session = _session();
      final store = InMemoryTokenStore(session);
      final repository = AuthRepository(
        api: _authApi(
          MockClient((request) async => http.Response('{}', 500)),
        ),
        store: store,
      );

      final restored = await repository.restore();

      expect(restored?.accessToken, 'token-1');
      expect(store.session, isNotNull);
    });

    test('restore clears an expired dev session', () async {
      final store = InMemoryTokenStore(
        _session(ttl: const Duration(hours: -1)),
      );
      final repository = AuthRepository(
        api: _authApi(
          MockClient((request) async => http.Response('{}', 500)),
        ),
        store: store,
      );

      expect(await repository.restore(), isNull);
      expect(store.session, isNull);
    });

    test('restore refreshes an expired Supabase session', () async {
      final store = InMemoryTokenStore(
        _session(
          mode: AuthMode.supabase,
          refreshToken: 'sb-refresh',
          ttl: const Duration(hours: -1),
        ),
      );
      final repository = AuthRepository(
        api: _authApi(
          MockClient(
            (request) async => _ok({
              'access_token': 'sb-token-2',
              'refresh_token': 'sb-refresh-2',
              'expires_in': 3600,
              'user': {'id': 'user-1', 'email': 'anna@example.com'},
            }),
          ),
          supabase: true,
        ),
        store: store,
      );

      final restored = await repository.restore();

      expect(restored?.accessToken, 'sb-token-2');
      expect(store.session?.accessToken, 'sb-token-2');
    });

    test('restore clears an unrefreshable Supabase session', () async {
      final store = InMemoryTokenStore(
        _session(
          mode: AuthMode.supabase,
          refreshToken: 'sb-refresh',
          ttl: const Duration(hours: -1),
        ),
      );
      final repository = AuthRepository(
        api: _authApi(
          MockClient((request) async => http.Response('{}', 400)),
          supabase: true,
        ),
        store: store,
      );

      expect(await repository.restore(), isNull);
      expect(store.session, isNull);
    });

    test('signIn uses dev auth when Supabase is not configured', () async {
      final store = InMemoryTokenStore();
      final repository = AuthRepository(
        api: _authApi(
          MockClient(
            (request) async => _ok({
              'accessToken': 'dev-token',
              'expiresIn': 3600,
              'user': {'id': 'dev_anna', 'email': 'anna@example.com'},
            }),
          ),
        ),
        store: store,
      );

      final session = await repository.signIn(
        email: 'anna@example.com',
        password: '',
      );

      expect(session.mode, AuthMode.dev);
      expect(store.session?.accessToken, 'dev-token');
    });
  });

  group('SyncRecord', () {
    test('round-trips through JSON and exposes a stable key', () {
      final record = SyncRecord(
        namespace: 'words',
        id: 'sleepy-hollow/mist',
        updatedAt: 1200,
        payload: const {'translationFr': 'la brume'},
      );

      final restored = SyncRecord.fromJson(
        jsonDecode(jsonEncode(record.toJson())),
      );

      expect(restored, isNotNull);
      expect(restored!.key, 'words:sleepy-hollow/mist');
      expect(restored.updatedAt, 1200);
      expect(restored.payload?['translationFr'], 'la brume');
    });

    test('tombstones drop the payload', () {
      final restored = SyncRecord.fromJson({
        'namespace': 'words',
        'id': 'sleepy-hollow/mist',
        'updatedAt': 1200,
        'deleted': true,
        'payload': {'word': 'mist'},
      });

      expect(restored?.deleted, isTrue);
      expect(restored?.payload, isNull);
    });

    test('rejects invalid records', () {
      expect(SyncRecord.fromJson(null), isNull);
      expect(SyncRecord.fromJson({'namespace': '', 'id': 'x'}), isNull);
      expect(
        SyncRecord.fromJson({
          'namespace': 'words',
          'id': 'x',
          'updatedAt': -1,
        }),
        isNull,
      );
      expect(
        SyncRecord.fromJson({
          'namespace': 'words',
          'id': 'x',
          'updatedAt': 'later',
        }),
        isNull,
      );
    });
  });

  group('SyncApi', () {
    test('push posts bearer records and parses the winners', () async {
      late http.Request captured;
      final record = SyncRecord(
        namespace: 'prefs',
        id: 'profile',
        updatedAt: 99,
        payload: const {'level': 'b1'},
      );
      final api = SyncApi(
        baseUrl: 'http://localhost:8000/',
        client: MockClient((request) async {
          captured = request;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return _ok({'serverRevision': 3, 'records': body['records']});
        }),
      );

      final result = await api.push(token: 'token-1', records: [record]);

      expect(captured.method, 'POST');
      expect(captured.url.path, '/v1/sync/push');
      expect(captured.headers['Authorization'], 'Bearer token-1');
      expect(result.revision, 3);
      expect(result.records.single.key, 'prefs:profile');
    });

    test('pull sends the cursor and parses records', () async {
      late http.Request captured;
      final api = SyncApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient((request) async {
          captured = request;
          return _ok({
            'revision': 7,
            'records': [
              {
                'namespace': 'reading',
                'id': 'sleepy-hollow/chapter-01',
                'updatedAt': 10,
                'payload': {'paragraphId': 'p-02', 'completed': false},
              },
            ],
          });
        }),
      );

      final result = await api.pull(token: 'token-1', since: 5);

      expect(captured.method, 'GET');
      expect(captured.url.path, '/v1/sync/pull');
      expect(captured.url.queryParameters['since'], '5');
      expect(result.revision, 7);
      expect(result.records.single.id, 'sleepy-hollow/chapter-01');
    });

    test('flags unauthorized responses', () async {
      final api = SyncApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient(
          (request) async => http.Response('{"detail":"expired"}', 401),
        ),
      );

      await expectLater(
        api.push(token: 'stale', records: const []),
        throwsA(
          isA<SyncException>().having(
            (error) => error.unauthorized,
            'unauthorized',
            isTrue,
          ),
        ),
      );
    });

    test('surfaces server errors and malformed payloads', () async {
      final failing = SyncApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient(
          (request) async =>
              http.Response('{"detail":"Trop de donnees."}', 413),
        ),
      );
      final malformed = SyncApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient(
          (request) async => _ok({'serverRevision': 'three', 'records': []}),
        ),
      );

      await expectLater(
        failing.push(token: 't', records: const []),
        throwsA(
          isA<SyncException>().having(
            (error) => error.message,
            'message',
            'Trop de donnees.',
          ),
        ),
      );
      await expectLater(
        malformed.push(token: 't', records: const []),
        throwsA(isA<SyncException>()),
      );
    });
  });

  group('SyncLocalStore', () {
    final savedAt = DateTime(2026, 11, 22, 10);

    Map<String, Object> seed() => {
      PrefsKeys.userLevel: 'a2',
      PrefsKeys.userInterests: <String>['mystery'],
      PrefsKeys.onboardingCompleted: true,
      PrefsKeys.themeMode: 'dark',
      PrefsKeys.settingsUpdated: 1000,
      PrefsKeys.readingPosition('sleepy-hollow', 'chapter-01'): 'p-02',
      PrefsKeys.readingUpdated('sleepy-hollow', 'chapter-01'): 3000,
      PrefsKeys.savedWords: <String>[
        jsonEncode(SavedWord(entry: _entry('mist'), savedAt: savedAt).toJson()),
      ],
      PrefsKeys.wordTombstones: jsonEncode({'sleepy-hollow/fog': 500}),
      PrefsKeys.srsCards: <String>[jsonEncode(_card('mist').toJson())],
      PrefsKeys.programSessions: <String>[
        jsonEncode(
          ProgramSession(date: DateTime(2026, 11, 21), minutes: 10).toJson(),
        ),
      ],
    };

    test('collect exports every synchronised namespace', () async {
      final harness = await _harness(seed());

      final records = harness.store.collect();
      final byKey = {for (final record in records) record.key: record};

      expect(records, hasLength(6));
      expect(
        byKey['reading:sleepy-hollow/chapter-01']?.payload,
        {'paragraphId': 'p-02', 'completed': false},
      );
      expect(byKey['reading:sleepy-hollow/chapter-01']?.updatedAt, 3000);
      expect(byKey['words:sleepy-hollow/mist']?.updatedAt, savedAt.millisecondsSinceEpoch);
      expect(byKey['words:sleepy-hollow/fog']?.deleted, isTrue);
      expect(byKey['words:sleepy-hollow/fog']?.updatedAt, 500);
      expect(byKey['srs:sleepy-hollow/mist'], isNotNull);
      expect(
        byKey['program:2026-11-21']?.updatedAt,
        DateTime(2026, 11, 21, 12).millisecondsSinceEpoch,
      );
      expect(byKey['prefs:profile']?.updatedAt, 1000);
      expect(byKey['prefs:profile']?.payload?['level'], 'a2');
      expect(byKey['prefs:profile']?.payload?['readingMode'], 'read');
    });

    test('apply writes remote reading, words, srs, program and prefs', () async {
      final harness = await _harness(seed());
      final fog = SavedWord(
        entry: _entry('fog'),
        savedAt: DateTime(2026, 11, 22, 11),
      );

      await harness.store.apply([
        SyncRecord(
          namespace: 'reading',
          id: 'sleepy-hollow/chapter-02',
          updatedAt: 9000,
          payload: const {'paragraphId': 'p-09', 'completed': true},
        ),
        SyncRecord(
          namespace: 'words',
          id: 'sleepy-hollow/mist',
          updatedAt: 10000,
          deleted: true,
        ),
        SyncRecord(
          namespace: 'words',
          id: 'sleepy-hollow/fog',
          updatedAt: 11000,
          payload: fog.toJson(),
        ),
        SyncRecord(
          namespace: 'srs',
          id: 'sleepy-hollow/fog',
          updatedAt: 12000,
          payload: _card('fog').toJson(),
        ),
        SyncRecord(
          namespace: 'program',
          id: '2026-11-20',
          updatedAt: 13000,
          payload: const {'date': '2026-11-20', 'minutes': 25},
        ),
        SyncRecord(
          namespace: 'prefs',
          id: 'profile',
          updatedAt: 14000,
          payload: const {
            'level': 'b2',
            'interests': ['gothic'],
            'onboardingCompleted': true,
            'themeMode': 'light',
            'readingMode': 'listen',
            'audioSpeed': 1.25,
          },
        ),
      ]);

      final reading = harness.reading.load(
        'sleepy-hollow',
        'chapter-02',
      );
      expect(reading.paragraphId, 'p-09');
      expect(reading.completed, isTrue);
      expect(
        reading.updatedAt?.millisecondsSinceEpoch,
        9000,
      );

      expect(harness.words.load().map((word) => word.entry.id), [
        'sleepy-hollow/fog',
      ]);
      expect(harness.words.loadTombstones(), isEmpty);
      expect(harness.srs.load().map((card) => card.entry.id), [
        'sleepy-hollow/mist',
        'sleepy-hollow/fog',
      ]);
      expect(
        harness.program.load().map((session) => session.minutes),
        [25, 10],
      );
      expect(harness.prefs.load().level, UserLevel.b2);
      expect(harness.prefs.load().themeMode, ThemeMode.light);
      expect(harness.prefs.loadReadingMode(), ReadingMode.listen);
      expect(harness.prefs.loadAudioSpeed(), 1.25);
      expect(harness.prefs.loadSettingsUpdatedMs(), 14000);
    });
  });

  group('SyncController', () {
    final savedAt = DateTime(2026, 11, 22, 10);
    final remoteProfileUpdated = DateTime(
      2026,
      11,
      22,
      12,
    ).millisecondsSinceEpoch;

    Future<ProviderContainer> containerWith(
      _Harness harness,
      MockClient syncClient, {
      AuthController Function()? auth,
      InMemoryTokenStore? tokenStore,
    }) async {
      final container = ProviderContainer(
        overrides: [
          prefsRepositoryProvider.overrideWithValue(harness.prefs),
          readingProgressRepositoryProvider.overrideWithValue(harness.reading),
          savedWordsRepositoryProvider.overrideWithValue(harness.words),
          srsRepositoryProvider.overrideWithValue(harness.srs),
          programRepositoryProvider.overrideWithValue(harness.program),
          tokenStoreProvider.overrideWithValue(
            tokenStore ?? InMemoryTokenStore(),
          ),
          authControllerProvider.overrideWith(
            auth ?? _SignedInAuthController.new,
          ),
          syncApiProvider.overrideWithValue(
            SyncApi(
              baseUrl: 'http://localhost:8000',
              client: syncClient,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('pushes, pulls and applies the latest winners', () async {
      final harness = await _harness({
        PrefsKeys.onboardingCompleted: true,
        PrefsKeys.userLevel: 'a2',
        PrefsKeys.savedWords: <String>[
          jsonEncode(
            SavedWord(entry: _entry('mist'), savedAt: savedAt).toJson(),
          ),
        ],
      });
      final remoteFog = SavedWord(
        entry: _entry('fog'),
        savedAt: DateTime(2026, 11, 22, 11),
      );
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-1');
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final pushed = body['records'] as List<dynamic>;
          expect(
            pushed.map((record) => (record as Map)['namespace']),
            containsAll(['words', 'prefs']),
          );
          return _ok({'serverRevision': 4, 'records': pushed});
        }
        return _ok({
          'revision': 5,
          'records': [
            {
              'namespace': 'words',
              'id': 'sleepy-hollow/mist',
              'updatedAt': 1,
              'deleted': false,
              'payload': SavedWord(
                entry: _entry('mist', translationFr: 'ancienne'),
                savedAt: DateTime(2020),
              ).toJson(),
            },
            {
              'namespace': 'words',
              'id': 'sleepy-hollow/fog',
              'updatedAt': 9000,
              'deleted': false,
              'payload': remoteFog.toJson(),
            },
            {
              'namespace': 'reading',
              'id': 'sleepy-hollow/chapter-01',
              'updatedAt': 9500,
              'payload': {'paragraphId': 'p-07', 'completed': true},
            },
            {
              'namespace': 'prefs',
              'id': 'profile',
              'updatedAt': remoteProfileUpdated,
              'payload': {
                'level': 'b2',
                'interests': ['gothic'],
                'onboardingCompleted': true,
                'themeMode': 'light',
                'readingMode': 'listen',
                'audioSpeed': 1.25,
              },
            },
          ],
        });
      });
      final container = await containerWith(harness, client);

      final succeeded = await container
          .read(syncControllerProvider.notifier)
          .syncNow();

      expect(succeeded, isTrue);
      expect(
        container.read(syncControllerProvider).status,
        SyncStatus.success,
      );
      expect(container.read(syncControllerProvider).lastSyncedAt, isNotNull);
      expect(harness.prefs.loadSyncCursor(), 5);
      expect(harness.prefs.loadLastSyncAt(), isNotNull);

      final words = harness.words.load();
      expect(words.map((word) => word.entry.id), [
        'sleepy-hollow/mist',
        'sleepy-hollow/fog',
      ]);
      expect(
        words.firstWhere((word) => word.entry.id == 'sleepy-hollow/mist')
            .entry
            .translationFr,
        'traduction',
      );
      expect(
        harness.reading.load('sleepy-hollow', 'chapter-01').paragraphId,
        'p-07',
      );
      expect(harness.prefs.load().level, UserLevel.b2);
      expect(harness.prefs.loadReadingMode(), ReadingMode.listen);
    });

    test('a 401 signs the user out and reports the failure', () async {
      final harness = await _harness({PrefsKeys.userLevel: 'a2'});
      final tokenStore = InMemoryTokenStore(_session());
      final container = await containerWith(
        harness,
        MockClient((request) async => http.Response('{"detail":"expired"}', 401)),
        tokenStore: tokenStore,
      );

      final succeeded = await container
          .read(syncControllerProvider.notifier)
          .syncNow();

      expect(succeeded, isFalse);
      expect(container.read(authControllerProvider).status, AuthStatus.signedOut);
      expect(tokenStore.session, isNull);
      final state = container.read(syncControllerProvider);
      expect(state.status, SyncStatus.failure);
      expect(state.error, 'Session expirée. Reconnectez-vous.');
    });

    test('refuses to sync while signed out', () async {
      final harness = await _harness({PrefsKeys.userLevel: 'a2'});
      final container = await containerWith(
        harness,
        MockClient((request) async => http.Response('{}', 200)),
        auth: _SignedOutAuthController.new,
      );

      final succeeded = await container
          .read(syncControllerProvider.notifier)
          .syncNow();

      expect(succeeded, isFalse);
      final state = container.read(syncControllerProvider);
      expect(state.status, SyncStatus.failure);
      expect(state.error, 'Connectez-vous pour synchroniser.');
    });

    test('a malformed pull leaves local data untouched', () async {
      final harness = await _harness({
        PrefsKeys.userLevel: 'a2',
        PrefsKeys.savedWords: <String>[
          jsonEncode(
            SavedWord(entry: _entry('mist'), savedAt: savedAt).toJson(),
          ),
        ],
      });
      final container = await containerWith(
        harness,
        MockClient((request) async {
          if (request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            return _ok({'serverRevision': 4, 'records': body['records']});
          }
          return _ok({
            'revision': 5,
            'records': [
              {'namespace': 'words', 'id': 'broken'},
            ],
          });
        }),
      );

      final succeeded = await container
          .read(syncControllerProvider.notifier)
          .syncNow();

      expect(succeeded, isFalse);
      expect(container.read(syncControllerProvider).status, SyncStatus.failure);
      expect(
        container.read(syncControllerProvider).error,
        'Réponse de synchronisation invalide.',
      );
      expect(harness.prefs.loadSyncCursor(), 0);
      expect(harness.words.load().single.entry.id, 'sleepy-hollow/mist');
    });
  });

  group('Saved word tombstones', () {
    Future<ProviderContainer> wordsContainer(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          savedWordsRepositoryProvider.overrideWithValue(
            SavedWordsRepository(preferences),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('removing a saved word records a tombstone', () async {
      final container = await wordsContainer({
        PrefsKeys.savedWords: <String>[
          jsonEncode(
            SavedWord(
              entry: _entry('mist'),
              savedAt: DateTime(2026, 11, 22),
            ).toJson(),
          ),
        ],
      });

      final added = await container
          .read(savedWordsProvider.notifier)
          .toggle(_entry('mist'));

      expect(added, isFalse);
      expect(container.read(savedWordsProvider), isEmpty);
      final tombstones = container
          .read(savedWordsRepositoryProvider)
          .loadTombstones();
      expect(tombstones.containsKey('sleepy-hollow/mist'), isTrue);
    });

    test('re-adding a word clears its tombstone', () async {
      final container = await wordsContainer({
        PrefsKeys.wordTombstones: jsonEncode({'sleepy-hollow/mist': 500}),
      });

      final added = await container
          .read(savedWordsProvider.notifier)
          .toggle(_entry('mist'));

      expect(added, isTrue);
      expect(container.read(savedWordsProvider), hasLength(1));
      expect(
        container
            .read(savedWordsRepositoryProvider)
            .loadTombstones(),
        isEmpty,
      );
    });
  });
}
