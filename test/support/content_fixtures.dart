Map<String, dynamic> validManifestJson() => {
  'schemaVersion': 1,
  'packVersion': '1.0.0',
  'id': 'sleepy-hollow',
  'title': 'The Legend of Sleepy Hollow',
  'titleFr': 'La Légende de Sleepy Hollow',
  'author': 'Washington Irving',
  'level': 'a2',
  'descriptionFr': 'Une vallée paisible que l’on dit hantée.',
  'chapters': <Map<String, dynamic>>[
    {
      'id': 'chapter-01',
      'number': 1,
      'title': 'A Quiet Valley',
      'asset': 'assets/content/sleepy-hollow-a2/chapters/chapter-01.json',
      'estimatedMinutes': 6,
      'newWordCount': 1,
    },
  ],
};

Map<String, dynamic> validVocabularyJson() => {
  'id': 'mist',
  'word': 'mist',
  'partOfSpeech': 'noun',
  'phonetic': '/mɪst/',
  'definitionEn': 'thin fog close to the ground',
  'translationFr': 'la brume',
  'example': 'A cold mist covered the fields.',
};

Map<String, dynamic> validChapterJson() => {
  'schemaVersion': 1,
  'id': 'chapter-01',
  'bookId': 'sleepy-hollow',
  'number': 1,
  'title': 'A Quiet Valley',
  'level': 'a2',
  'paragraphs': <Map<String, dynamic>>[
    {
      'id': 'p-01',
      'segments': <Map<String, dynamic>>[
        {'text': 'The '},
        {'text': 'mist', 'vocabId': 'mist'},
        {'text': ' covered the fields.'},
      ],
    },
  ],
  'vocabulary': <Map<String, dynamic>>[validVocabularyJson()],
};

Map<String, dynamic> validAudioChapterJson({int durationMs = 3000}) {
  final json = validChapterJson();
  json['schemaVersion'] = 2;
  json['audio'] = <String, dynamic>{
    'asset': 'assets/content/sleepy-hollow-a2/audio/chapter-01.mp3',
    'durationMs': durationMs,
    'voice': 'en-US-AriaNeural',
    'words': <Map<String, dynamic>>[
      {'text': 'The', 'startMs': 0, 'endMs': 300},
      {'text': 'mist', 'startMs': 300, 'endMs': 700},
      {'text': 'covered', 'startMs': 700, 'endMs': 1200},
      {'text': 'the', 'startMs': 1200, 'endMs': 1400},
      {'text': 'fields', 'startMs': 1400, 'endMs': 2000},
    ],
  };
  return json;
}

Map<String, dynamic> audioOf(Map<String, dynamic> chapter) {
  return chapter['audio'] as Map<String, dynamic>;
}

List<dynamic> audioWordsOf(Map<String, dynamic> chapter) {
  return audioOf(chapter)['words'] as List<dynamic>;
}

Map<String, dynamic> firstParagraph(Map<String, dynamic> chapter) {
  return (chapter['paragraphs'] as List<dynamic>).first as Map<String, dynamic>;
}

List<dynamic> segmentsOf(Map<String, dynamic> paragraph) {
  return paragraph['segments'] as List<dynamic>;
}

Map<String, dynamic> firstVocabulary(Map<String, dynamic> chapter) {
  return (chapter['vocabulary'] as List<dynamic>).first as Map<String, dynamic>;
}
