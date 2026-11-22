import 'pack_store.dart';
import 'pack_store_stub.dart'
    if (dart.library.io) 'pack_store_io.dart'
    as platform;

PackStore createPackStore({String? rootOverride}) =>
    platform.createPackStore(rootOverride: rootOverride);

bool isHostTestEnvironment() => platform.isHostTestEnvironment();
