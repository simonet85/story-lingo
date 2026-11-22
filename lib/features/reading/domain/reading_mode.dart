enum ReadingMode {
  read('read'),
  listen('listen'),
  readListen('read_listen');

  const ReadingMode(this.id);

  final String id;

  bool get usesAudio => this != ReadingMode.read;

  bool get showsText => this != ReadingMode.listen;

  static ReadingMode fromId(String? id) => switch (id) {
    'listen' => ReadingMode.listen,
    'read_listen' => ReadingMode.readListen,
    _ => ReadingMode.read,
  };
}
