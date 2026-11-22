sealed class DownloadException implements Exception {
  const DownloadException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class DownloadConfigException extends DownloadException {
  const DownloadConfigException(super.message);
}

class DownloadUnsupportedException extends DownloadException {
  const DownloadUnsupportedException(super.message);
}

class DownloadNetworkException extends DownloadException {
  const DownloadNetworkException(super.message);
}

class DownloadHttpException extends DownloadException {
  const DownloadHttpException(super.message);
}

class DownloadIntegrityException extends DownloadException {
  const DownloadIntegrityException(super.message);
}

class DownloadStorageException extends DownloadException {
  const DownloadStorageException(super.message);
}

class DownloadBusyException extends DownloadException {
  const DownloadBusyException(super.message);
}

class DownloadCancelledException extends DownloadException {
  const DownloadCancelledException() : super('Téléchargement annulé.');
}

class DownloadCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const DownloadCancelledException();
  }
}
