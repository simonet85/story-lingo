import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/data/just_audio_engine.dart';
import '../../audio/domain/audio_engine.dart';

typedef AudioEngineFactory = AudioEngine Function();

final audioEngineFactoryProvider = Provider<AudioEngineFactory>(
  (ref) => JustAudioEngine.new,
);
