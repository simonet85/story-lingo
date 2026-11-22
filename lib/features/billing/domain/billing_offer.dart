enum BillingOfferKind { monthly, yearly }

class BillingOffer {
  const BillingOffer({
    required this.id,
    required this.kind,
    required this.titleFr,
    required this.priceLabel,
    required this.periodLabel,
    this.badgeFr,
  });

  final String id;
  final BillingOfferKind kind;
  final String titleFr;
  final String priceLabel;
  final String periodLabel;
  final String? badgeFr;

  bool get isYearly => kind == BillingOfferKind.yearly;
}
