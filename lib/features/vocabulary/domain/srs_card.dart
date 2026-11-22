import 'package:fsrs/fsrs.dart';

import 'word_entry.dart';

/// One vocabulary card scheduled by FSRS.
///
/// [entry] is a full snapshot so the card stays readable without the pack.
class SrsCard {
  const SrsCard({
    required this.entry,
    required this.card,
    required this.introducedAt,
    required this.reviews,
    this.firstReviewedAt,
    this.lastReviewedAt,
  });

  final WordEntry entry;
  final Card card;
  final DateTime introducedAt;
  final DateTime? firstReviewedAt;
  final DateTime? lastReviewedAt;
  final int reviews;

  bool get isNew => card.lastReview == null;

  Map<String, Object?> toJson() => {
    'entry': entry.toJson(),
    'card': card.toMap(),
    'introducedAt': introducedAt.millisecondsSinceEpoch,
    'firstReviewedAt': firstReviewedAt?.millisecondsSinceEpoch,
    'lastReviewedAt': lastReviewedAt?.millisecondsSinceEpoch,
    'reviews': reviews,
  };

  static SrsCard? fromJson(Object? source) {
    if (source is! Map) return null;
    final entry = WordEntry.fromJson(source['entry']);
    if (entry == null) return null;
    final rawCard = source['card'];
    if (rawCard is! Map) return null;
    final Card card;
    try {
      card = Card.fromMap(Map<String, dynamic>.from(rawCard));
    } catch (_) {
      return null;
    }
    final introducedAt = _readDate(source['introducedAt']);
    if (introducedAt == null) return null;
    final reviews = source['reviews'];
    return SrsCard(
      entry: entry,
      card: card,
      introducedAt: introducedAt,
      firstReviewedAt: _readDate(source['firstReviewedAt']),
      lastReviewedAt: _readDate(source['lastReviewedAt']),
      reviews: reviews is int && reviews >= 0 ? reviews : 0,
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    return null;
  }
}

/// Stable 32-bit FNV-1a hash, used as the numeric FSRS card id.
int srsCardIdFor(String entryId) {
  var hash = 0x811c9dc5;
  for (final unit in entryId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
