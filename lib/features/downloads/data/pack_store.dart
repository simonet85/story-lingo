import 'dart:typed_data';

abstract interface class PackSink {
  void add(List<int> data);

  Future<void> close();

  Future<void> abort();
}

/// File-system surface used by the offline download pipeline.
///
/// Paths are always relative POSIX paths inside the storylingo data root.
abstract interface class PackStore {
  bool get isSupported;

  Future<void> ensureRoot();

  Future<void> writeBytes(String path, List<int> bytes);

  Future<PackSink> openSink(String path);

  Future<void> writeStringAtomic(String path, String value);

  Future<String?> readString(String path);

  Future<Uint8List?> readBytes(String path);

  Future<bool> exists(String path);

  Future<void> rename(String from, String to);

  Future<void> deleteTree(String path);

  Future<List<String>> listNames(String path);

  Future<String> absolutePath(String path);
}

abstract final class PackPaths {
  static const String index = 'downloads.json';
  static const String packs = 'packs';
  static const String staging = 'staging';
  static const String trash = 'trash';

  static String pack(String bookId) => '$packs/$bookId';

  static String manifest(String bookId) => '${pack(bookId)}/manifest.json';

  static String descriptor(String bookId) => '${pack(bookId)}/pack.json';

  static String relative(String bookId, String filePath) =>
      '${pack(bookId)}/$filePath';

  static String stagingDirectory(String bookId, String token) =>
      '$staging/$bookId-$token';

  static String trashDirectory(String bookId, String token) =>
      '$trash/$bookId-$token';
}
