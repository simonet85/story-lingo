import 'package:material_ui/material_ui.dart';

@immutable
class ChapterReadingState {
  const ChapterReadingState({
    this.paragraphId,
    this.completed = false,
    this.updatedAt,
  });

  static const empty = ChapterReadingState();

  final String? paragraphId;
  final bool completed;
  final DateTime? updatedAt;

  bool get hasPosition => paragraphId != null;
}
