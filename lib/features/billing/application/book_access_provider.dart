import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/data/content_repository.dart';
import '../../downloads/application/download_providers.dart';
import 'entitlement_provider.dart';

enum BookAccess { free, installed, subscribed, locked, unknown }

final bookAccessProvider = Provider.family<BookAccess, String>((ref, bookId) {
  if (ref.watch(installedPackProvider(bookId)) != null) {
    return BookAccess.installed;
  }
  if (ref.watch(isEntitledProvider)) return BookAccess.subscribed;

  final catalogue = ref.watch(catalogueProvider);
  final view = catalogue.value;
  if (view == null) return BookAccess.unknown;
  for (final book in view.books) {
    if (book.id != bookId) continue;
    return book.isFree ? BookAccess.free : BookAccess.locked;
  }
  // The catalogue is loaded but does not know this id: let the reader surface
  // its usual "unknown book" error instead of spinning forever.
  return BookAccess.free;
});
