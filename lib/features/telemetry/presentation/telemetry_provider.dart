import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vocabulary/presentation/srs_provider.dart';
import '../data/telemetry_repository.dart';
import '../domain/telemetry_event.dart';

final telemetryRepositoryProvider = Provider<TelemetryRepository>(
  (ref) => throw UnimplementedError(
    'telemetryRepositoryProvider must be overridden at app start',
  ),
);

final telemetryProvider =
    NotifierProvider<TelemetryController, List<TelemetryEvent>>(
      TelemetryController.new,
    );

class TelemetryController extends Notifier<List<TelemetryEvent>> {
  @override
  List<TelemetryEvent> build() {
    return ref.watch(telemetryRepositoryProvider).load();
  }

  Future<void> record(
    String name, {
    Map<String, Object?> properties = const {},
  }) async {
    if (name.trim().isEmpty) return;
    final event = TelemetryEvent(
      name: name,
      at: ref.read(nowProvider)().toUtc(),
      properties: sanitizeTelemetryProperties(properties),
    );
    final next = [...state, event];
    final start = next.length > TelemetryRepository.maxEvents
        ? next.length - TelemetryRepository.maxEvents
        : 0;
    final trimmed = List<TelemetryEvent>.unmodifiable(next.skip(start));

    await ref.read(telemetryRepositoryProvider).save(trimmed);
    state = trimmed;
  }

  Future<void> clear() async {
    await ref.read(telemetryRepositoryProvider).save(const []);
    state = const [];
  }
}
