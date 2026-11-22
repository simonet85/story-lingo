/// Minimal audio surface used by the reading feature.
///
/// Kept deliberately small so widget tests can inject a deterministic
/// fake instead of mocking platform channels.
abstract class AudioEngine {
  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;

  Future<void> loadAsset(String asset);
  Future<void> loadUrl(String url);
  Future<void> loadFile(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}
