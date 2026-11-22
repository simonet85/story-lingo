import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pack_store_factory.dart';

enum DownloadPlatform { web, mobile, other }

final downloadPlatformProvider = Provider<DownloadPlatform>((ref) {
  if (kIsWeb) return DownloadPlatform.web;
  if (isHostTestEnvironment()) return DownloadPlatform.other;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => DownloadPlatform.mobile,
    _ => DownloadPlatform.other,
  };
});
