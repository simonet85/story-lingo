import 'dart:async';

import 'package:storylingo/features/audio/domain/audio_engine.dart';

class FakeAudioEngine implements AudioEngine {
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _playing = StreamController<bool>.broadcast();

  final List<String> loadedAssets = [];
  final List<String> loadedUrls = [];
  final List<String> loadedFiles = [];
  final List<Duration> seeks = [];
  final List<double> speeds = [];
  int playCalls = 0;
  int pauseCalls = 0;
  bool disposed = false;
  bool failLoad = false;

  @override
  Stream<Duration> get positionStream => _positions.stream;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Future<void> loadAsset(String asset) async {
    if (failLoad) throw StateError('Unable to load $asset');
    loadedAssets.add(asset);
  }

  @override
  Future<void> loadUrl(String url) async {
    if (failLoad) throw StateError('Unable to load $url');
    loadedUrls.add(url);
  }

  @override
  Future<void> loadFile(String path) async {
    if (failLoad) throw StateError('Unable to load $path');
    loadedFiles.add(path);
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    speeds.add(speed);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _positions.close();
    await _playing.close();
  }

  void emitPosition(Duration position) => _positions.add(position);

  void emitPlaying(bool playing) => _playing.add(playing);
}
