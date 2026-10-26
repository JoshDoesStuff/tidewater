import 'jp_han.dart';

/// Which CJK typeface suits a string. The same Han character is drawn
/// differently in Japanese and Chinese, so a title needs the right font first.
enum CjkScript { japanese, chinese }

final _jpHan = jpHan.runes.toSet();

bool _isHan(int c) => (c >= 0x3400 && c <= 0x4DBF) || (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0xF900 && c <= 0xFAFF);

bool _isKana(int c) => (c >= 0x3040 && c <= 0x30FF) || (c >= 0x31F0 && c <= 0x31FF) || (c >= 0xFF66 && c <= 0xFF9F);

/// Japanese when there is any kana (hiragana, katakana, halfwidth), or when
/// every Han character also exists in Japanese encodings. Chinese when a Han
/// character exists only in simplified Chinese (and there is no kana). Text
/// that is not Han at all (Latin, Korean, ...) is [CjkScript.japanese], which
/// only decides the fallback order and changes nothing for it.
CjkScript cjkScriptOf(String text) {
  var chinese = false;
  for (final c in text.runes) {
    if (_isKana(c)) return CjkScript.japanese;
    if (!chinese && _isHan(c) && !_jpHan.contains(c)) chinese = true;
  }
  return chinese ? CjkScript.chinese : CjkScript.japanese;
}
