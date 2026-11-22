class ContentOfflineException implements Exception {
  const ContentOfflineException(this.message);

  final String message;

  @override
  String toString() => 'ContentOfflineException: $message';
}
