import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/core/models/album.dart';
import 'package:tidewater/core/models/artist.dart';
import 'package:tidewater/core/models/track.dart';
import 'package:tidewater/core/search/library_index.dart';

Track song(String id, String title, String artist, {String album = 'Album'}) => Track(
      id: id,
      title: title,
      artist: artist,
      albumId: 'al-$id',
      albumTitle: album,
      duration: const Duration(seconds: 200),
    );

void main() {
  final index = LibraryIndex(
    artists: const [
      Artist(id: 'ar1', name: 'The Beatles', albumCount: 12),
      Artist(id: 'ar2', name: 'Beck', albumCount: 4),
      Artist(id: 'ar3', name: 'Björk', albumCount: 8),
    ],
    albums: const [
      Album(id: 'al1', title: 'Abbey Road', artist: 'The Beatles'),
      Album(id: 'al2', title: 'Night Transit', artist: 'Koji'),
      Album(id: 'al3', title: 'ベストアルバム', artist: 'マイマイ'),
    ],
    songs: [
      song('s1', 'Last Night Transit', 'Koji'),
      song('s2', 'Come Together', 'The Beatles', album: 'Abbey Road'),
      song('s3', 'Hyperballad', 'Björk'),
    ],
  );

  List<String> titles(String q) => [for (final s in index.suggest(q)) s.title];

  test('a start of the title ranks above a word inside it', () {
    final t = titles('night');
    expect(t.first, 'Night Transit', reason: 'album starting with night');
    expect(t, contains('Last Night Transit'));
    expect(t.indexOf('Night Transit'), lessThan(t.indexOf('Last Night Transit')));
  });

  test('an exact name beats a longer one and artists come before albums and songs on a tie', () {
    expect(titles('beck').first, 'Beck');
    final kinds = [for (final s in index.suggest('the beatles')) s.kind];
    expect(kinds.first, SuggestionKind.artist);
  });

  test('accents, case and width do not matter', () {
    expect(titles('bjork'), contains('Björk'));
    expect(titles('BJÖRK'), contains('Björk'));
    expect(titles('ｂｅｃｋ'), contains('Beck'));
  });

  test('hiragana finds katakana and the other way round', () {
    expect(titles('べすと'), contains('ベストアルバム'));
    expect(titles('まいまい'), contains('ベストアルバム'), reason: 'typed as the album artist');
  });

  test('typing the artist with the title finds the song', () {
    expect(titles('koji last'), contains('Last Night Transit'));
  });

  test('one letter off still finds it', () {
    expect(titles('beatels'), contains('The Beatles'));
    expect(titles('hyperbalad'), contains('Hyperballad'));
    expect(titles('zzzz'), isEmpty);
  });

  test('matches carry where to highlight', () {
    final s = index.suggest('transit').firstWhere((s) => s.title == 'Last Night Transit');
    expect(s.title.substring(s.matchStart, s.matchStart + s.matchLength).toLowerCase(), 'transit');
  });

  test('no one kind crowds the list out', () {
    final many = LibraryIndex(songs: [for (var i = 0; i < 50; i++) song('s$i', 'Love $i', 'Band')]);
    expect(many.suggest('love').length, 4);
    expect(many.suggest('love', perKind: 10).length, 8);
  });

  test('an empty query suggests nothing', () {
    expect(index.suggest('   '), isEmpty);
  });
}
