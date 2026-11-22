import 'dart:typed_data';

import 'pack_store.dart';

PackStore createPackStore({String? rootOverride}) => StubPackStore();

bool isHostTestEnvironment() => false;

class StubPackStore implements PackStore {
  @override
  bool get isSupported => false;

  @override
  Future<void> ensureRoot() async {}

  @override
  Future<void> writeBytes(String path, List<int> bytes) async {
    throw UnsupportedError(
      'Offline storage is not available on this platform.',
    );
  }

  @override
  Future<PackSink> openSink(String path) async {
    throw UnsupportedError(
      'Offline storage is not available on this platform.',
    );
  }

  @override
  Future<void> writeStringAtomic(String path, String value) async {
    throw UnsupportedError(
      'Offline storage is not available on this platform.',
    );
  }

  @override
  Future<String?> readString(String path) async => null;

  @override
  Future<Uint8List?> readBytes(String path) async => null;

  @override
  Future<bool> exists(String path) async => false;

  @override
  Future<void> rename(String from, String to) async {
    throw UnsupportedError(
      'Offline storage is not available on this platform.',
    );
  }

  @override
  Future<void> deleteTree(String path) async {}

  @override
  Future<List<String>> listNames(String path) async => const [];

  @override
  Future<String> absolutePath(String path) async => '';
}
