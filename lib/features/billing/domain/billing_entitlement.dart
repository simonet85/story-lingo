class BillingEntitlement {
  const BillingEntitlement({
    required this.active,
    required this.source,
    this.productId,
    this.expiresAt,
  });

  static const BillingEntitlement inactive = BillingEntitlement(
    active: false,
    source: 'none',
  );

  factory BillingEntitlement.fromJson(Object? source) {
    if (source is! Map<String, dynamic>) return inactive;
    final active = source['active'];
    final rawSource = source['source'];
    final productId = source['productId'];
    final rawExpiresAt = source['expiresAt'];
    final expiresAt = rawExpiresAt is String
        ? DateTime.tryParse(rawExpiresAt)
        : null;
    return BillingEntitlement(
      active: active is bool ? active : false,
      source: rawSource is String && rawSource.isNotEmpty ? rawSource : 'server',
      productId: productId is String && productId.isNotEmpty ? productId : null,
      expiresAt: expiresAt,
    );
  }

  final bool active;
  final String source;
  final String? productId;
  final DateTime? expiresAt;

  bool isActiveAt(DateTime now) =>
      active && (expiresAt == null || expiresAt!.isAfter(now));

  Map<String, Object?> toJson() => {
    'active': active,
    'source': source,
    'productId': productId,
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
  };

  BillingEntitlement copyWith({
    bool? active,
    String? source,
    String? productId,
    DateTime? expiresAt,
  }) => BillingEntitlement(
    active: active ?? this.active,
    source: source ?? this.source,
    productId: productId ?? this.productId,
    expiresAt: expiresAt ?? this.expiresAt,
  );
}

class BillingException implements Exception {
  const BillingException(this.message);

  final String message;

  @override
  String toString() => message;
}
