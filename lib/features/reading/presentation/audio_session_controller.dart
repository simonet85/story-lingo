import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../audio/domain/audio_engine.dart';
import '../../audio/domain/audio_speed.dart';
import '../../content/domain/chapter.dart';
import '../domain/karaoke_track.dart';

typedef AudioSpeedSaver = Future<void> Function(double speed);

class AudioSessionController extends ChangeNotifier {
  AudioSessionController({
    required this.engine,
    required Chapter chapter,
    required double initialSpeed,
    required this.onSpeedChanged,
  }) : assert(chapter.audio != null, 'Chapter has no audio track.'),
       audio = chapter.audio!,
       track = KaraokeTrack.fromChapter(chapter),
       _speed = initialSpeed {
    _positionSub = engine.positionStream.listen(_onPosition);
    _playingSub = engine.playingStream.listen(_onPlaying);
    _updateActiveWord();
  }

  final AudioEngine engine;
  final ChapterAudio audio;
  final KaraokeTrack track;
  final AudioSpeedSaver onSpeedChanged;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;

  Duration _position = Duration.zero;
  Duration _lastNotifiedPosition = Duration.zero;
  bool _playing = false;
  bool _loaded = false;
  bool _loading = false;
  bool _failed = false;
  bool _finished = false;
  bool _disposed = false;
  double _speed;
  int? _activeWordIndex;
  int? _activeSentenceIndex;

  Duration get duration => Duration(milliseconds: audio.durationMs);

  Duration get position => _position;

  bool get isPlaying => _playing;

  bool get isReady => _loaded;

  bool get isLoading => _loading;

  bool get hasError => _failed;

  String? get errorMessage => _failed ? 'Audio indisponible.' : null;

  double get speed => _speed;

  int? get activeWordIndex => _activeWordIndex;

  int? get activeSentenceIndex => _activeSentenceIndex;

  String? get activeParagraphId {
    final index = _activeWordIndex;
    if (index == null) return null;
    return track.paragraphIdAtWord(index);
  }

  bool get isFinished => _finished || (_loaded && _position >= duration);

  Future<void> ensureLoaded() async {
    if (_disposed || _loaded || _loading) return;
    _loading = true;
    _failed = false;
    notifyListeners();
    try {
      if (audio.localFile case final localFile?) {
        await engine.loadFile(localFile);
      } else if (audio.url case final url?) {
        await engine.loadUrl(url);
      } else {
        await engine.loadAsset(audio.asset!);
      }
      await engine.setSpeed(_speed);
      _loaded = true;
      _failed = false;
      _updateActiveWord();
    } catch (_) {
      _loaded = false;
      _failed = true;
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> retry() async {
    if (_loading) return;
    _loaded = false;
    _failed = false;
    await ensureLoaded();
  }

  Future<void> togglePlay() async {
    if (_playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    if (!_loaded) {
      await ensureLoaded();
    }
    if (!_loaded || _disposed) return;
    if (isFinished) {
      await seekTo(Duration.zero);
    }
    _finished = false;
    unawaited(
      engine.play().catchError((Object _) {
        if (_disposed) return;
        _failed = true;
        notifyListeners();
      }),
    );
  }

  Future<void> pause() async {
    if (!_loaded || _disposed) return;
    try {
      await engine.pause();
    } catch (_) {
      // Pausing must never break the reading session.
    }
  }

  Future<void> seekTo(Duration position) async {
    if (!_loaded || _disposed) return;
    final clampedMs = position.inMilliseconds.clamp(0, duration.inMilliseconds);
    final clamped = Duration(milliseconds: clampedMs);
    _position = clamped;
    _finished = false;
    _updateActiveWord();
    _lastNotifiedPosition = clamped;
    notifyListeners();
    try {
      await engine.seek(clamped);
    } catch (_) {
      // The position stream will resynchronize on the next event.
    }
  }

  Future<void> seekBy(Duration delta) => seekTo(_position + delta);

  Future<void> setSpeed(double speed) async {
    if (!audioSpeedOptions.contains(speed)) return;
    _speed = speed;
    notifyListeners();
    try {
      await onSpeedChanged(speed);
    } catch (_) {
      // Preference persistence is best-effort.
    }
    if (!_loaded || _disposed) return;
    try {
      await engine.setSpeed(speed);
    } catch (_) {
      // Keep the UI speed and let the next load apply it.
    }
  }

  void _onPlaying(bool playing) {
    if (_disposed) return;
    _playing = playing;
    if (!playing &&
        _loaded &&
        _position >= duration - const Duration(milliseconds: 250)) {
      _finished = true;
    }
    notifyListeners();
  }

  void _onPosition(Duration position) {
    if (_disposed) return;
    final clampedMs = position.inMilliseconds.clamp(0, duration.inMilliseconds);
    final clamped = Duration(milliseconds: clampedMs);
    if (clamped == _position) return;
    _position = clamped;
    if (_position < duration - const Duration(milliseconds: 250)) {
      _finished = false;
    }
    final karaokeChanged = _updateActiveWord();
    final moved =
        (_position - _lastNotifiedPosition).abs() >=
        const Duration(milliseconds: 200);
    if (karaokeChanged || moved) {
      _lastNotifiedPosition = _position;
      notifyListeners();
    }
  }

  bool _updateActiveWord() {
    if (!track.isAvailable) {
      final changed = _activeWordIndex != null || _activeSentenceIndex != null;
      _activeWordIndex = null;
      _activeSentenceIndex = null;
      return changed;
    }
    final index = track.wordIndexAt(_position);
    final sentence = index == null ? null : track.sentenceIndexAtWord(index);
    final changed =
        index != _activeWordIndex || sentence != _activeSentenceIndex;
    _activeWordIndex = index;
    _activeSentenceIndex = sentence;
    return changed;
  }

  @override
  void dispose() {
    _disposed = true;
    _positionSub?.cancel();
    _playingSub?.cancel();
    unawaited(engine.dispose());
    super.dispose();
  }
}
