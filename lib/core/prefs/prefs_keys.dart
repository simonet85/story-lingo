abstract final class PrefsKeys {
  static const String schemaVersion = 'prefs.version';
  static const String onboardingCompleted = 'onboarding.completed';
  static const String userLevel = 'user.level';
  static const String userInterests = 'user.interests';
  static const String themeMode = 'settings.theme_mode';
  static const String readingMode = 'settings.reading_mode';
  static const String audioSpeed = 'settings.audio_speed';
  static const String savedWords = 'words.saved';
  static const String srsCards = 'srs.cards';
  static const String programSessions = 'program.sessions';
  static const String telemetryEvents = 'telemetry.events';
  static const String settingsUpdated = 'settings.updated';
  static const String wordTombstones = 'sync.tombstones.words';
  static const String syncCursor = 'sync.cursor';
  static const String syncLastAt = 'sync.last_at';
  static const String entitlementCache = 'billing.entitlement';
  static const String demoEntitlement = 'billing.demo';

  static const String readingPositionPrefix = 'reading.position.';
  static const String readingCompletedPrefix = 'reading.completed.';
  static const String readingUpdatedPrefix = 'reading.updated.';

  static String readingPosition(String bookId, String chapterId) =>
      '$readingPositionPrefix$bookId.$chapterId';

  static String readingCompleted(String bookId, String chapterId) =>
      '$readingCompletedPrefix$bookId.$chapterId';

  static String readingUpdated(String bookId, String chapterId) =>
      '$readingUpdatedPrefix$bookId.$chapterId';
}
