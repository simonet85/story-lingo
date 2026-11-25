class MobileMoneyProduct {
  const MobileMoneyProduct({
    required this.productId,
    required this.amount,
    required this.days,
    required this.currency,
  });

  static const String monthlyProductId = 'storylingo_pro_monthly_xaf';
  static const String yearlyProductId = 'storylingo_pro_yearly_xaf';

  /// Known product, or null when the payload is incomplete.
  static MobileMoneyProduct? tryParse(Map<String, Object?> json) {
    final productId = json['productId'];
    final amount = json['amount'];
    final days = json['days'];
    final rawCurrency = json['currency'];
    if (productId != monthlyProductId && productId != yearlyProductId) {
      return null;
    }
    if (amount is! int || amount <= 0 || days is! int || days <= 0) {
      return null;
    }
    return MobileMoneyProduct(
      productId: productId as String,
      amount: amount,
      days: days,
      currency: rawCurrency is String && rawCurrency.isNotEmpty
          ? rawCurrency
          : 'XAF',
    );
  }

  final String productId;
  final int amount;
  final int days;
  final String currency;

  bool get isYearly => productId == yearlyProductId;

  String get titleFr => isYearly ? 'Annuel' : 'Mensuel';

  String get priceLabel {
    final label = currency == 'XAF' ? 'FCFA' : currency;
    return '${_groupDigits(amount)} $label';
  }

  String get periodLabel => isYearly ? '/ an' : '/ mois';

  String _groupDigits(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }
}
