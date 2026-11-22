import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vocabulary/presentation/srs_provider.dart';
import '../data/program_repository.dart';
import '../domain/program_progress.dart';
import '../domain/program_session.dart';

final programRepositoryProvider = Provider<ProgramRepository>(
  (ref) => throw UnimplementedError(
    'programRepositoryProvider must be overridden at app start',
  ),
);

final programProvider =
    NotifierProvider<ProgramController, List<ProgramSession>>(
      ProgramController.new,
    );

final programProgressProvider = Provider<ProgramProgress>((ref) {
  final now = ref.read(nowProvider)();
  return computeProgramProgress(ref.watch(programProvider), now: now);
});

class ProgramController extends Notifier<List<ProgramSession>> {
  @override
  List<ProgramSession> build() => ref.watch(programRepositoryProvider).load();

  Future<ProgramSession> recordSession({
    required DateTime at,
    required int elapsedSeconds,
  }) async {
    final date = startOfLocalDay(at);
    final minutes = math.max(1, math.min(240, (elapsedSeconds / 60).ceil()));

    final next = [...state];
    final index = next.indexWhere(
      (session) => isSameLocalDay(session.date, date),
    );
    final ProgramSession session;
    if (index >= 0) {
      session = ProgramSession(
        date: date,
        minutes: math.max(next[index].minutes, minutes),
        updatedAt: at,
      );
      next[index] = session;
    } else {
      session = ProgramSession(date: date, minutes: minutes, updatedAt: at);
      next.add(session);
    }
    next.sort((a, b) => a.date.compareTo(b.date));

    await ref.read(programRepositoryProvider).save(next);
    state = List.unmodifiable(next);
    return session;
  }
}
