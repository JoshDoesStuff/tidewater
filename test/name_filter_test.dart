import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/core/models/album.dart';
import 'package:tidewater/core/models/json_util.dart';

void main() {
  tearDown(() => NameFilter.hideJapanese = false);

  test('names are untouched while the setting is off', () {
    expect(NameFilter.apply('宇多田ヒカル'), '宇多田ヒカル');
  });

  group('hiding Japanese', () {
    setUp(() => NameFilter.hideJapanese = true);

    test('drops kana and kanji and tidies what is left', () {
      expect(NameFilter.apply('YOASOBI (ヨアソビ)'), 'YOASOBI');
      expect(NameFilter.apply('Utada 宇多田'), 'Utada');
    });

    test('an all-Japanese name becomes a dash; Latin names are kept', () {
      expect(NameFilter.apply('宇多田ヒカル'), '—');
      expect(NameFilter.apply('Daft Punk'), 'Daft Punk');
    });

    test('models are filtered as they are parsed', () {
      final a = Album.fromJson({'id': '1', 'name': 'First Love 初恋', 'artist': '宇多田ヒカル'});
      expect(a.title, 'First Love');
      expect(a.artist, '—');
    });
  });
}
