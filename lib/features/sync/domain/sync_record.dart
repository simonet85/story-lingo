class SyncRecord {
  const SyncRecord({
    required this.namespace,
    required this.id,
    required this.updatedAt,
    this.deleted = false,
    this.payload,
  });

  final String namespace;
  final String id;

  /// Client edit time in milliseconds; drives last-write-wins.
  final int updatedAt;
  final bool deleted;
  final Map<String, Object?>? payload;

  String get key => '$namespace:$id';

  Map<String, Object?> toJson() => {
    'namespace': namespace,
    'id': id,
    'updatedAt': updatedAt,
    'deleted': deleted,
    'payload': payload,
  };

  static SyncRecord? fromJson(Object? source) {
    if (source is! Map) return null;
    final namespace = source['namespace'];
    final id = source['id'];
    final updatedAt = source['updatedAt'];
    if (namespace is! String || namespace.isEmpty) return null;
    if (id is! String || id.isEmpty) return null;
    if (updatedAt is! int || updatedAt < 0) return null;
    final deleted = source['deleted'] == true;
    final rawPayload = source['payload'];
    final payload = rawPayload is Map
        ? Map<String, Object?>.from(rawPayload)
        : null;
    return SyncRecord(
      namespace: namespace,
      id: id,
      updatedAt: updatedAt,
      deleted: deleted,
      payload: deleted ? null : payload,
    );
  }
}
