import 'package:just_audio/just_audio.dart';

import '../domain/audio_engine.dart';

class JustAudioEngine implements AudioEngine {
  JustAudioEngine() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Future<void> loadAsset(String asset) async {
    await _player.setAsset(asset);
  }

  @override
  Future<void> loadUrl(String url) async {
    await _player.setUrl(url);
  }

  @override
  Future<void> loadFile(String path) async {
    await _player.setFilePath(path);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> dispose() => _player.dispose();
}
