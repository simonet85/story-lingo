import 'package:flutter_test/flutter_test.dart';
import 'package:storylingo/features/content/domain/chapter.dart';
import 'package:storylingo/features/reading/presentation/audio_session_controller.dart';

import 'support/content_fixtures.dart';
import 'support/fake_audio_engine.dart';

void main() {
  late FakeAudioEngine engine;
  late List<double> savedSpeeds;

  AudioSessionController buildController({double initialSpeed = 1.0}) {
    engine = FakeAudioEngine();
    savedSpeeds = [];
    return AudioSessionController(
      engine: engine,
      chapter: Chapter.fromJson(validAudioChapterJson()),
      initialSpeed: initialSpeed,
      onSpeedChanged: (speed) async => savedSpeeds.add(speed),
    );
  }

  test('loads the asset and applies the saved speed', () async {
    final controller = buildController(initialSpeed: 1.25);

    await controller.ensureLoaded();

    expect(engine.loadedAssets, [
      'assets/content/sleepy-hollow-a2/audio/chapter-01.mp3',
    ]);
    expect(engine.speeds, [1.25]);
    expect(controller.isReady, isTrue);
    expect(controller.isLoading, isFalse);
    expect(controller.hasError, isFalse);
    expect(controller.duration, const Duration(milliseconds: 3000));

    controller.dispose();
    expect(engine.disposed, isTrue);
  });

  test('reports a load failure and can retry', () async {
    final controller = buildController();
    engine.failLoad = true;

    await controller.ensureLoaded();

    expect(controller.hasError, isTrue);
    expect(controller.isReady, isFalse);
    expect(controller.errorMessage, 'Audio indisponible.');

    engine.failLoad = false;
    await controller.retry();

    expect(controller.hasError, isFalse);
    expect(controller.isReady, isTrue);
    expect(engine.loadedAssets, hasLength(1));

    controller.dispose();
  });

  test('play and pause follow the engine streams', () async {
    final controller = buildController();
    await controller.ensureLoaded();

    await controller.play();
    engine.emitPlaying(true);
    await pumpEventQueue();

    expect(controller.isPlaying, isTrue);
    expect(engine.playCalls, 1);

    await controller.pause();
    expect(engine.pauseCalls, 1);

    engine.emitPlaying(false);
    await pumpEventQueue();
    expect(controller.isPlaying, isFalse);

    controller.dispose();
  });

  test('maps the audio position to the active word and sentence', () async {
    final controller = buildController();
    await controller.ensureLoaded();

    engine.emitPosition(const Duration(milliseconds: 350));
    await pumpEventQueue();

    expect(controller.activeWordIndex, 1);
    expect(controller.activeSentenceIndex, 0);

    engine.emitPosition(const Duration(milliseconds: 750));
    await pumpEventQueue();
    expect(controller.activeWordIndex, 2);

    controller.dispose();
  });

  test('clamps seeks to the audio bounds', () async {
    final controller = buildController();
    await controller.ensureLoaded();

    await controller.seekBy(const Duration(seconds: -15));
    expect(controller.position, Duration.zero);
    expect(engine.seeks.last, Duration.zero);

    await controller.seekTo(const Duration(hours: 1));
    expect(controller.position, const Duration(milliseconds: 3000));
    expect(engine.seeks.last, const Duration(milliseconds: 3000));

    engine.emitPosition(const Duration(seconds: 10));
    await pumpEventQueue();
    expect(controller.position, const Duration(milliseconds: 3000));

    controller.dispose();
  });

  test('speed changes are applied and persisted', () async {
    final controller = buildController();
    await controller.ensureLoaded();

    await controller.setSpeed(1.5);
    expect(controller.speed, 1.5);
    expect(savedSpeeds, [1.5]);
    expect(engine.speeds.last, 1.5);

    await controller.setSpeed(2.0);
    expect(controller.speed, 1.5);
    expect(savedSpeeds, [1.5]);

    controller.dispose();
  });

  test('finished audio replays from the start', () async {
    final controller = buildController();
    await controller.ensureLoaded();

    engine.emitPosition(const Duration(milliseconds: 3000));
    engine.emitPlaying(false);
    await pumpEventQueue();

    expect(controller.isFinished, isTrue);

    await controller.play();
    expect(controller.isFinished, isFalse);
    expect(controller.position, Duration.zero);
    expect(engine.seeks.last, Duration.zero);
    expect(engine.playCalls, 1);

    controller.dispose();
  });
}
