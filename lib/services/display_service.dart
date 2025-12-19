import 'package:shared_preferences/shared_preferences.dart';

/// ?⑥뼱 ?쒖떆 諛⑹떇 愿由??쒕퉬??
class DisplayService {
  static final DisplayService instance = DisplayService._internal();
  factory DisplayService() => instance;
  DisplayService._internal();

  static const String _keyFuriganaDisplayMode = 'furiganaDisplayMode';
  String _displayMode = 'parentheses';

  /// ?쒖떆 諛⑹떇 珥덇린??
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _displayMode = prefs.getString(_keyFuriganaDisplayMode) ?? 'parentheses';
  }

  /// ?꾩옱 ?쒖떆 諛⑹떇 媛?몄삤湲?
  String get displayMode => _displayMode;

  /// ?쒖떆 諛⑹떇 ?ㅼ젙
  Future<void> setDisplayMode(String mode) async {
    _displayMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFuriganaDisplayMode, mode);
  }

  /// 愿꾪샇 蹂묎린 諛⑹떇?몄? ?뺤씤
  bool get isParenthesesMode => _displayMode == 'parentheses';

  /// ?꾨━媛??諛⑹떇?몄? ?뺤씤
  bool get isFuriganaMode => _displayMode == 'furigana';
}


