import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/theme/album_scheme.dart';
import 'package:tidewater/app/theme/app_theme.dart';
import 'package:tidewater/core/color/cover_seed.dart';

void main() {
  final a = AlbumScheme.of(const CoverSeed(0xffd32f2f), Brightness.dark);
  final b = AlbumScheme.of(const CoverSeed(0xff1565c0), Brightness.dark);

  test('the fade starts and ends exactly on the two schemes', () {
    final t = ColorSchemeTween(begin: a, end: b);
    expect(t.transform(0), same(a));
    expect(t.transform(1), same(b));
  });

  test('a 180 Hz recolor produces about 40 schemes, not 144', () {
    final t = ColorSchemeTween(begin: a, end: b);
    final seen = <ColorScheme>{};
    for (var i = 0; i <= 144; i++) {
      seen.add(t.transform(i / 144));
    }
    expect(seen.length, lessThanOrEqualTo(ColorSchemeTween.steps + 2));
    expect(seen.length, greaterThan(20), reason: 'still a smooth-looking fade');
  });

  test('frames inside one step share the same scheme object', () {
    final t = ColorSchemeTween(begin: a, end: b);
    expect(t.transform(.5), same(t.transform(.5 + 1 / 400)));
  });

  test('moving the end retargets instead of returning a stale scheme', () {
    final t = ColorSchemeTween(begin: a, end: b);
    final first = t.transform(.5);
    t.end = AlbumScheme.of(const CoverSeed(0xff2e7d32), Brightness.dark);
    expect(t.transform(.5), isNot(same(first)));
    expect(t.transform(.5).primary, isNot(first.primary));
  });

  test('the middle of the fade is between the two ends', () {
    final t = ColorSchemeTween(begin: a, end: b);
    expect(t.transform(.5).primary, Color.lerp(a.primary, b.primary, .5));
  });

  test('ThemeData is built once per scheme object', () {
    final memo = ThemeMemo();
    var built = 0;
    ThemeData build(ColorScheme s) {
      built++;
      return AppTheme.fromScheme(s);
    }

    final t = ColorSchemeTween(begin: a, end: b);
    for (var i = 0; i < 100; i++) {
      memo.of(t.transform(.3 + i / 100000), build);
    }
    expect(built, 1);
    memo.of(t.transform(.9), build);
    expect(built, 2);
  });
}
