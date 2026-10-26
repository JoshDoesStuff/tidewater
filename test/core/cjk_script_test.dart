import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/core/text/cjk_script.dart';

void main() {
  CjkScript of(String s) => cjkScriptOf(s);

  test('kana means Japanese, even beside Han characters', () {
    expect(of('ハローセカイ / バーチャル'), CjkScript.japanese);
    expect(of('初音ミク × 鏡音リン'), CjkScript.japanese);
    expect(of('そこに在る、光。'), CjkScript.japanese);
  });

  test('Han characters that Japanese does not use mean Chinese', () {
    expect(of('危机合约 黄铁·利刃'), CjkScript.chinese);
    expect(of('这是一首歌'), CjkScript.chinese);
    expect(of('明日方舟 音律联觉'), CjkScript.chinese);
  });

  test('Han that both languages share stays Japanese', () {
    expect(of('八王子P'), CjkScript.japanese);
    expect(of('黒魔'), CjkScript.japanese);
    expect(of('塞壬唱片'), CjkScript.japanese);
  });

  test('kana wins over a simplified character in the same title', () {
    expect(of('これは这'), CjkScript.japanese);
  });

  test('text without CJK is left alone', () {
    expect(of('Monster Siren Records'), CjkScript.japanese);
    expect(of(''), CjkScript.japanese);
  });
}
