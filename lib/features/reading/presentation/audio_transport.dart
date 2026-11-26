import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../audio/domain/audio_speed.dart';
import 'audio_session_controller.dart';

String formatAudioTime(Duration duration) {
  final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final minutes = seconds ~/ 60;
  final remainder = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remainder';
}

String _speedLabel(double speed) {
  final text = speed == speed.roundToDouble()
      ? speed.toStringAsFixed(1)
      : '$speed';
  return '$text×';
}

class AudioTransportBar extends StatelessWidget {
  const AudioTransportBar({required this.controller, super.key});

  final AudioSessionController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: controller.hasError
                  ? _AudioError(controller: controller)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AudioProgress(controller: controller),
                        Row(
                          children: [
                            const Spacer(),
                            _SeekButton(
                              label: 'Reculer de 15 secondes',
                              text: '−15 s',
                              delta: const Duration(seconds: -15),
                              controller: controller,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _PlayButton(controller: controller),
                            const SizedBox(width: AppSpacing.sm),
                            _SeekButton(
                              label: 'Avancer de 15 secondes',
                              text: '+15 s',
                              delta: const Duration(seconds: 15),
                              controller: controller,
                            ),
                            const Spacer(),
                            _SpeedButton(controller: controller),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class AudioListenPanel extends StatelessWidget {
  const AudioListenPanel({
    required this.controller,
    required this.chapterTitle,
    super.key,
  });

  final AudioSessionController controller;
  final String chapterTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: ClipRRect(
                      borderRadius: AppRadii.cardLargeBorder,
                      child: SizedBox(
                        width: 280,
                        height: 280,
                        child: Image.asset(
                          'assets/onboarding/listening.jpg',
                          fit: BoxFit.cover,
                          semanticLabel:
                              'Personne installée dans un fauteuil, casque sur '
                              'les oreilles, livre sur les genoux',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Écouter le chapitre',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    chapterTitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (controller.hasError)
                    _AudioError(controller: controller)
                  else ...[
                    _AudioProgress(controller: controller),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SeekButton(
                          label: 'Reculer de 15 secondes',
                          text: '−15 s',
                          delta: const Duration(seconds: -15),
                          controller: controller,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _PlayButton(controller: controller, large: true),
                        const SizedBox(width: AppSpacing.lg),
                        _SeekButton(
                          label: 'Avancer de 15 secondes',
                          text: '+15 s',
                          delta: const Duration(seconds: 15),
                          controller: controller,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(child: _SpeedButton(controller: controller)),
                    if (controller.isLoading) ...[
                      const SizedBox(height: AppSpacing.md),
                      const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AudioProgress extends StatefulWidget {
  const _AudioProgress({required this.controller});

  final AudioSessionController controller;

  @override
  State<_AudioProgress> createState() => _AudioProgressState();
}

class _AudioProgressState extends State<_AudioProgress> {
  double? _dragMilliseconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final durationMs = controller.duration.inMilliseconds.toDouble();
    final positionMs =
        _dragMilliseconds ??
        controller.position.inMilliseconds.toDouble().clamp(0, durationMs);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Slider(
          value: positionMs,
          max: durationMs,
          onChanged: controller.isReady
              ? (value) => setState(() => _dragMilliseconds = value)
              : null,
          onChangeEnd: (value) {
            _dragMilliseconds = null;
            controller.seekTo(Duration(milliseconds: value.round()));
          },
        ),
        Row(
          children: [
            Text(
              formatAudioTime(Duration(milliseconds: positionMs.round())),
              style: labelStyle,
            ),
            const Spacer(),
            Text(formatAudioTime(controller.duration), style: labelStyle),
          ],
        ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.controller, this.large = false});

  final AudioSessionController controller;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final finished = controller.isFinished;
    final playing = controller.isPlaying;
    final label = playing
        ? 'Pause audio'
        : finished
        ? "Rejouer l'audio"
        : 'Lecture audio';
    final icon = playing
        ? Icons.pause
        : finished
        ? Icons.replay
        : Icons.play_arrow;
    final size = large ? 72.0 : 56.0;

    return IconButton.filled(
      tooltip: label,
      onPressed: controller.isReady && !controller.hasError
          ? controller.togglePlay
          : null,
      iconSize: large ? 36 : 28,
      style: IconButton.styleFrom(minimumSize: Size.square(size)),
      icon: Icon(icon),
    );
  }
}

class _SeekButton extends StatelessWidget {
  const _SeekButton({
    required this.label,
    required this.text,
    required this.delta,
    required this.controller,
  });

  final String label;
  final String text;
  final Duration delta;
  final AudioSessionController controller;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: TextButton(
        onPressed: controller.isReady && !controller.hasError
            ? () => controller.seekBy(delta)
            : null,
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Text(text),
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.controller});

  final AudioSessionController controller;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Vitesse de lecture',
      child: TextButton(
        onPressed: () => showAudioSpeedSheet(context, controller),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(_speedLabel(controller.speed)),
      ),
    );
  }
}

Future<void> showAudioSpeedSheet(
  BuildContext context,
  AudioSessionController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                'Vitesse de lecture',
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final speed in audioSpeedOptions)
              ListTile(
                title: Text(_speedSheetLabel(speed)),
                selected: controller.speed == speed,
                trailing: controller.speed == speed
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  controller.setSpeed(speed);
                  Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
}

String _speedSheetLabel(double speed) => switch (speed) {
  0.8 => '0.8× — Lent',
  1.0 => '1.0× — Normal',
  1.25 => '1.25× — Un peu plus rapide',
  1.5 => '1.5× — Rapide',
  _ => _speedLabel(speed),
};

class _AudioError extends StatelessWidget {
  const _AudioError({required this.controller});

  final AudioSessionController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              controller.errorMessage ?? 'Audio indisponible.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: controller.retry,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
