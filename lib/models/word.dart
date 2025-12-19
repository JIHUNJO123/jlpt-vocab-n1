import 'dart:convert';

/// ?⑥뼱 紐⑤뜽 (JLPT ?숈뒿??- ?쇰낯???⑥뼱??
/// ?⑥뼱 湲곕낯 ?뺣낫 + ?꾨쿋??踰덉뿭 + ?숈쟻 踰덉뿭
class Word {
  final int id;
  final String word; // ?꾩껜 ?⑥뼱 (?쒖옄+?덈씪媛???쇳빀)
  final String? kanji; // ?쒖옄 遺遺?
  final String? hiragana; // ?덈씪媛???쎄린
  final String
  level; // JLPT ?덈꺼: N5, N4, N3, N2, N1
  final String partOfSpeech;
  final String definition; // ?占쎌뼱 ?占쎌쓽
  final String example; // ?占쎌뼱 ?占쎈Ц
  final String
  category; // 移댄뀒怨좊━: Academic, Environment, Technology, Health, Education ??
  bool isFavorite;

  // ?占쎌옣 踰덉뿭 ?占쎌씠??(words.json?占쎌꽌 濡쒕뱶)
  final Map<String, Map<String, String>>? translations;

  // 踰덉뿭???占쎌뒪??(?占쏙옙??占쎌뿉 ?占쎌젙??
  String? translatedDefinition;
  String? translatedExample;

  Word({
    required this.id,
    required this.word,
    this.kanji,
    this.hiragana,
    required this.level,
    required this.partOfSpeech,
    required this.definition,
    required this.example,
    this.category = 'General',
    this.isFavorite = false,
    this.translations,
    this.translatedDefinition,
    this.translatedExample,
  });

  /// ?占쎌옣 踰덉뿭 媛?占쎌삤占?
  String? getEmbeddedTranslation(String langCode, String fieldType) {
    if (translations == null) return null;
    final langData = translations![langCode];
    if (langData == null) return null;
    return langData[fieldType];
  }

  /// JSON?占쎌꽌 ?占쎌꽦 (?占쎌뼱 ?占쎈낯 + ?占쎌옣 踰덉뿭)
  factory Word.fromJson(Map<String, dynamic> json) {
    // translations ?占쎌떛 (??媛吏 ?占쎌떇 吏??
    Map<String, Map<String, String>>? translations;

    // ?占쎌떇 1: translations 媛앹껜
    if (json['translations'] != null) {
      translations = {};
      (json['translations'] as Map<String, dynamic>).forEach((langCode, data) {
        if (data is Map<String, dynamic>) {
          translations![langCode] = {
            'definition': data['definition']?.toString() ?? '',
            'example': data['example']?.toString() ?? '',
          };
        }
      });
    }

    // ?占쎌떇 2: flat ?占쎌떇 (definition_ja, example_ja ??
    final langCodes = [
      'ko',
      'ja',
      'zh',
      'zh_cn',
      'zh_tw',
      'es',
      'fr',
      'de',
      'pt',
      'vi',
      'ar',
      'th',
      'ru',
    ];
    for (final lang in langCodes) {
      final defKey = 'definition_$lang';
      final exKey = 'example_$lang';
      if (json[defKey] != null || json[exKey] != null) {
        translations ??= {};
        // zh_cn -> zh占?留ㅽ븨
        final normalizedLang = lang == 'zh_cn' ? 'zh' : lang;
        translations[normalizedLang] = {
          'definition': json[defKey]?.toString() ?? '',
          'example': json[exKey]?.toString() ?? '',
        };
      }
    }

    return Word(
      id: json['id'],
      word: json['word'],
      kanji: json['kanji'],
      hiragana: json['hiragana'],
      level: json['level'],
      partOfSpeech: json['partOfSpeech'],
      definition: json['definition'],
      example: json['example'],
      category: json['category'] ?? 'General',
      isFavorite: json['isFavorite'] == 1 || json['isFavorite'] == true,
      translations: translations,
    );
  }

  /// DB 留듭뿉???占쎌꽦 (translations JSON ?占쎌떛 ?占쏀븿)
  factory Word.fromDb(Map<String, dynamic> json) {
    // DB?占쎌꽌 translations ?占쎈뱶 ?占쎌떛
    Map<String, Map<String, String>>? translations;
    if (json['translations'] != null && json['translations'] is String) {
      try {
        final decoded = jsonDecode(json['translations'] as String);
        if (decoded is Map<String, dynamic>) {
          translations = {};
          decoded.forEach((langCode, data) {
            if (data is Map<String, dynamic>) {
              translations![langCode] = {
                'definition': data['definition']?.toString() ?? '',
                'example': data['example']?.toString() ?? '',
              };
            }
          });
        }
      } catch (e) {
        print('Error parsing translations JSON: $e');
      }
    }

    return Word(
      id: json['id'] as int,
      word: json['word'] as String,
      kanji: json['kanji'] as String?,
      hiragana: json['hiragana'] as String?,
      level: json['level'] as String,
      partOfSpeech: json['partOfSpeech'] as String,
      definition: json['definition'] as String,
      example: json['example'] as String,
      category: json['category'] as String? ?? 'General',
      isFavorite: (json['isFavorite'] as int) == 1,
      translations: translations,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'level': level,
      'partOfSpeech': partOfSpeech,
      'definition': definition,
      'example': example,
      'category': category,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  /// 踰덉뿭???占쎌쓽 媛?占쎌삤占?(踰덉뿭 ?占쎌쑝占??占쎌뼱 ?占쎈낯)
  String getDefinition(bool useTranslation) {
    if (useTranslation &&
        translatedDefinition != null &&
        translatedDefinition!.isNotEmpty) {
      return translatedDefinition!;
    }
    return definition;
  }

  /// 踰덉뿭???占쎈Ц 媛?占쎌삤占?(踰덉뿭 ?占쎌쑝占??占쎌뼱 ?占쎈낯)
  String getExample(bool useTranslation) {
    if (useTranslation &&
        translatedExample != null &&
        translatedExample!.isNotEmpty) {
      return translatedExample!;
    }
    return example;
  }

  /// ?쒖옄? ?덈씪媛?섎? ?④퍡 ?쒖떆 (?쒖떆 諛⑹떇???곕씪)
  /// [displayMode]: 'parentheses' (愿꾪샇 蹂묎린) ?먮뒗 'furigana' (?꾨━媛??
  String getDisplayWord({String displayMode = 'parentheses'}) {
    if (kanji != null && hiragana != null && kanji!.isNotEmpty && hiragana!.isNotEmpty) {
      if (displayMode == 'furigana') {
        // ?꾨━媛??諛⑹떇: 繇잆겧??[?잆겧?귙겗]
        return '$kanji [$hiragana]';
      } else {
        // 愿꾪샇 蹂묎린 諛⑹떇: 繇잆겧??(?잆겧?귙겗)
        return '$kanji ($hiragana)';
      }
    }
    return word;
  }

  Word copyWith({
    int? id,
    String? word,
    String? kanji,
    String? hiragana,
    String? level,
    String? partOfSpeech,
    String? definition,
    String? example,
    String? category,
    bool? isFavorite,
    Map<String, Map<String, String>>? translations,
    String? translatedDefinition,
    String? translatedExample,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      kanji: kanji ?? this.kanji,
      hiragana: hiragana ?? this.hiragana,
      level: level ?? this.level,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      definition: definition ?? this.definition,
      example: example ?? this.example,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      translations: translations ?? this.translations,
      translatedDefinition: translatedDefinition ?? this.translatedDefinition,
      translatedExample: translatedExample ?? this.translatedExample,
    );
  }
}

