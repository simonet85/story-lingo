class SessionClock {
  SessionClock({required this.totalSeconds}) : assert(totalSeconds > 0);

  final int totalSeconds;

  int _ticks = 0;

  int get elapsedSeconds => _ticks;

  int get remainingSeconds => totalSeconds - _ticks;

  void tick() => _ticks++;
}

String formatSessionTime(int seconds) {
  final overtime = seconds < 0;
  final absolute = seconds.abs();
  final minutes = absolute ~/ 60;
  final remainder = absolute % 60;
  final label = '$minutes:${remainder.toString().padLeft(2, '0')}';
  return overtime ? '+$label' : label;
}
