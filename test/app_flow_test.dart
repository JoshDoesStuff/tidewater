import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/library_providers.dart';
import 'package:tidewater/app/app.dart' show routerProvider;
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/session_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/core/api/api_exception.dart';
import 'package:tidewater/core/api/server_config.dart';
import 'package:tidewater/core/api/session_store.dart';
import 'package:tidewater/core/models/album.dart';
import 'package:tidewater/ui/pages/library_page.dart' show firstIndexForLetter;
import 'package:tidewater/ui/pages/widgets/album_card.dart' show AlbumCard, MediaCard, PlaylistCard, TrackCard;
import 'package:tidewater/ui/pages/widgets/song_row.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/ui/widgets/expressive_buttons.dart';
import 'package:tidewater/ui/widgets/heart_button.dart';
import 'package:tidewater/ui/widgets/effects/particle_burst.dart';

import 'support/fake_library.dart';
import 'support/pump.dart';
import 'support/test_app.dart';

const _unreachable = ApiException(ApiErrorKind.unreachable, 'down');

Finder _field(int i) => find.byType(TextField).at(i);

Future<void> _signIn(WidgetTester tester, {String url = 'music.example.com', String user = 'josh', String secret = 'sesame'}) async {
  await tester.enterText(_field(0), url);
  await tester.enterText(_field(1), user);
  await tester.enterText(_field(2), secret);
  await tester.tap(find.text('Connect'));
  await advance(tester, const Duration(seconds: 3));
}

void main() {
  group('login', () {
    testWidgets('starts at the login screen when no server is saved', (tester) async {
      await pumpApp(tester, signedIn: false);
      expect(find.text('Connect to your Navidrome server'), findsOneWidget);
      expect(find.text('Jump back in'), findsNothing);
      expect(find.text('Shuffle all'), findsNothing);
      await disposeApp(tester);
    });

    testWidgets('signing in saves the server and opens Home', (tester) async {
      final store = MemorySessionStore();
      final container = await pumpApp(tester, signedIn: false, store: store);
      await _signIn(tester);
      expect(find.text('Jump back in'), findsOneWidget);
      expect(find.text('Connect to your Navidrome server'), findsNothing);
      expect(container.read(sessionProvider), isNotNull);
      final saved = store.config!;
      expect(saved.baseUrl.toString(), 'https://music.example.com');
      expect((saved.credentials as PasswordCredentials).username, 'josh');
      await disposeApp(tester);
    });

    testWidgets('empty fields say what is missing instead of calling the server', (tester) async {
      final api = FakeLibraryApi();
      await pumpApp(tester, signedIn: false, api: api);
      await tester.tap(find.text('Connect'));
      await advance(tester, const Duration(seconds: 1));
      expect(find.text('Enter your server address.'), findsOneWidget);
      await tester.enterText(_field(0), 'music.example.com');
      await tester.tap(find.text('Connect'));
      await advance(tester, const Duration(seconds: 1));
      expect(find.text('Enter your username and password.'), findsOneWidget);
      expect(api.calls, isEmpty);
      await disposeApp(tester);
    });

    testWidgets('wrong password shows the error, a retry then works', (tester) async {
      final api = FakeLibraryApi(failWith: const ApiException(ApiErrorKind.badCredentials, 'Wrong username or password.', code: 40));
      await pumpApp(tester, signedIn: false, api: api);
      await _signIn(tester, secret: 'nope');
      expect(find.text('Wrong username or password.'), findsOneWidget);
      expect(find.text('Jump back in'), findsNothing);
      api.failWith = null;
      await tester.tap(find.text('Connect'));
      await advance(tester, const Duration(seconds: 3));
      expect(find.text('Jump back in'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('an untrusted certificate can be trusted for this server', (tester) async {
      final trusted = <bool>[];
      await pumpApp(
        tester,
        signedIn: false,
        factory: (config) {
          trusted.add(config.trustBadCertificate);
          return FakeLibraryApi(
            failWith: config.trustBadCertificate ? null : const ApiException(ApiErrorKind.tls, "The server's security certificate isn't trusted."),
          );
        },
      );
      await _signIn(tester, url: 'https://nas.local');
      expect(find.textContaining('certificate'), findsWidgets);
      expect(find.text('Trust this server'), findsOneWidget);
      await tester.tap(find.text('Trust this server'));
      await advance(tester, const Duration(seconds: 3));
      expect(find.text('Jump back in'), findsOneWidget);
      // Probe without trust, probe with trust, then the signed-in client.
      expect(trusted, [false, true, true]);
      await disposeApp(tester);
    });

    testWidgets('an API key replaces the username and password', (tester) async {
      final store = MemorySessionStore();
      await pumpApp(tester, signedIn: false, store: store);
      expect(find.text('Username'), findsOneWidget);
      await tester.tap(find.text('API key'));
      await advance(tester, const Duration(seconds: 1));
      expect(find.text('Username'), findsNothing);
      await tester.enterText(_field(0), 'music.example.com');
      await tester.enterText(_field(1), 'k-123');
      await tester.tap(find.text('Connect'));
      await advance(tester, const Duration(seconds: 3));
      expect(find.text('Jump back in'), findsOneWidget);
      final saved = store.config!.credentials;
      expect(saved, isA<ApiKeyCredentials>());
      expect((saved as ApiKeyCredentials).apiKey, 'k-123');
      await disposeApp(tester);
    });


    testWidgets('signing out from the avatar returns to login and stops playback', (tester) async {
      final store = MemorySessionStore(testServer);
      final container = await pumpApp(tester, store: store);
      await container.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
      await advance(tester, const Duration(seconds: 1));
      expect(container.read(playbackProvider).playing, isTrue);

      await tester.tap(find.byKey(const Key('account-avatar')));
      await advance(tester, const Duration(milliseconds: 600));
      expect(find.text('josh'), findsOneWidget);
      await tester.tap(find.text('Sign out or switch server'));
      await advance(tester, const Duration(seconds: 3));

      expect(find.text('Connect to your Navidrome server'), findsOneWidget);
      expect(store.config, isNull);
      expect(container.read(playbackProvider).queue, isEmpty);
      expect(container.read(sessionProvider), isNull);
      await disposeApp(tester);
    });
  });

  group('home', () {
    testWidgets('shows an error with Retry when the server is unreachable, then recovers', (tester) async {
      final api = FakeLibraryApi(failWith: _unreachable);
      await pumpApp(tester, api: api);
      expect(find.textContaining('Can\'t reach your server'), findsWidgets);
      expect(find.text('Retry'), findsWidgets);
      expect(find.text('Glass Orchard'), findsNothing);
      api.failWith = null;
      await tester.tap(find.text('Retry').first);
      await advance(tester, const Duration(seconds: 3));
      expect(find.text('Glass Orchard'), findsWidgets);
      await disposeApp(tester);
    });

    testWidgets('an empty library says so', (tester) async {
      await pumpApp(tester, api: FakeLibraryApi(albums: const []));
      expect(find.text('Your library is empty'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('hero cards and rows come from the server', (tester) async {
      await pumpApp(tester);
      // recent -> heroes; frequent -> Most played; newest -> Recently added.
      expect(find.textContaining('Album · '), findsNWidgets(3));
      expect(find.text('Continue listening'), findsNothing, reason: 'nothing queued yet');
      expect(find.byType(AlbumCard), findsWidgets);
      expect(find.text('Recently added'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('the mini player only appears once something is queued', (tester) async {
      final container = await pumpApp(tester);
      expect(find.byTooltip('Next'), findsNothing);
      final card = tester.widget<AlbumCard>(find.byType(AlbumCard).first);
      await tester.tap(find.byWidget(card));
      await advance(tester, const Duration(seconds: 2));
      expect(container.read(activeAlbumIdProvider), card.album.id);
      expect(find.byTooltip('Next'), findsOneWidget);
      expect(find.text('Continue listening'), findsOneWidget);
      await container.read(playbackProvider.notifier).toggle();
      await disposeApp(tester);
    });

    testWidgets('Home is one scrolling page with no tabs', (tester) async {
      await pumpApp(tester);
      expect(find.byType(ExpressiveChip), findsNothing);
      expect(find.text('Jump back in'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('"Show all" opens the Library on that tab', (tester) async {
      final container = await pumpApp(tester);
      await tester.tap(find.text('Show all').first); // Recently added
      await advance(tester, const Duration(seconds: 2));
      expect(find.text('12 albums'), findsOneWidget);
      expect(container.read(librarySortProvider), LibrarySort.recentlyAdded);
      await disposeApp(tester);
    });
  });

  group('playing from the library', () {
    testWidgets('skipping inside an album keeps the album active and moves the track', (tester) async {
      final container = await pumpApp(tester);
      final player = container.read(playbackProvider.notifier);
      await player.playAlbum(fakeAlbums[1]); // three tracks
      await advance(tester, const Duration(seconds: 1));
      expect(container.read(currentTrackIdProvider), 't-a1');
      expect(container.read(playbackProvider).queue, hasLength(3));
      await player.next();
      await advance(tester, const Duration(seconds: 1));
      expect(container.read(currentTrackIdProvider), 't-a1-1');
      expect(container.read(activeAlbumIdProvider), 'a1');
      await player.stop();
      await advance(tester, const Duration(seconds: 1));
      expect(container.read(currentTrackProvider), isNull);
      expect(container.read(activeAlbumIdProvider), isNull);
      await disposeApp(tester);
    });

    testWidgets('a failed play request shows a message instead of throwing', (tester) async {
      final api = FakeLibraryApi();
      final container = await pumpApp(tester, api: api);
      api.failWith = _unreachable;
      await container.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
      await advance(tester, const Duration(milliseconds: 500));
      expect(find.text('Can\'t reach the server. Check your connection.'), findsOneWidget);
      expect(container.read(playbackProvider).queue, isEmpty);
      await advance(tester, const Duration(seconds: 5));
      expect(container.read(toastProvider), isNull);
      await disposeApp(tester);
    });

    testWidgets('Shuffle all queues random songs from the server', (tester) async {
      final api = FakeLibraryApi();
      final container = await pumpApp(tester, api: api);
      await tester.tap(find.text('Shuffle all'));
      await advance(tester, const Duration(seconds: 1));
      expect(api.calls, contains('getRandomSongs'));
      expect(container.read(playbackProvider).queue, isNotEmpty);
      await container.read(playbackProvider.notifier).toggle();
      await disposeApp(tester);
    });

    testWidgets('an artist card opens the artist instead of starting playback', (tester) async {
      final container = await pumpApp(tester);
      await tester.tap(find.text('Artists').first); // sidebar
      await advance(tester, const Duration(seconds: 2));
      final card = find.ancestor(of: find.text('Ana Soleil').first, matching: find.byType(MediaCard));
      await tester.tapAt(tester.getTopLeft(card) + const Offset(50, 50)); // the cover
      await advance(tester, const Duration(seconds: 1));
      expect(container.read(routerProvider).state.uri.path, '/artist/ar-a2');
      expect(container.read(playbackProvider).queue, isEmpty);
      await disposeApp(tester);
    });
  });

  group('library', () {
    Future<ProviderContainer> openLibrary(WidgetTester tester, {FakeLibraryApi? api}) async {
      final container = await pumpApp(tester, api: api);
      await tester.tap(find.text('Library'));
      await advance(tester, const Duration(seconds: 2));
      return container;
    }

    testWidgets('sorts on the server and shows the new order', (tester) async {
      final api = FakeLibraryApi();
      await openLibrary(tester, api: api);
      await tester.tap(find.text('Recently added').first);
      await advance(tester, const Duration(milliseconds: 600));
      await tester.tap(find.widgetWithText(PopupMenuItem<LibrarySort>, 'Artist')); // menu item
      await advance(tester, const Duration(seconds: 2));
      expect(api.calls, contains('getAlbumList:alphabeticalByArtist:0'));
      // Ana Soleil sorts before Dune Parade, Eli Marsh ...
      final first = tester.getTopLeft(find.text('Low Tide Letters').last);
      final second = tester.getTopLeft(find.text('Velvet Static').last);
      expect(first.dx < second.dx || first.dy < second.dy, isTrue);
      await disposeApp(tester);
    });

    testWidgets('filters by genre and counts what is shown', (tester) async {
      await openLibrary(tester);
      await tester.tap(find.text('Genre'));
      await advance(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Folk'));
      await advance(tester, const Duration(seconds: 2));
      expect(find.text('3 folk albums'), findsOneWidget);
      expect(find.text('Glass Orchard'), findsNothing);
      expect(find.text('Low Tide Letters'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('ctrl+click on Genre opens a grid to pick several genres', (tester) async {
      await openLibrary(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Genre'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await advance(tester, const Duration(milliseconds: 600));
      expect(find.text('Pick genres'), findsOneWidget);
      await tester.tap(find.text('Folk'));
      await tester.pump();
      await tester.tap(find.text('Electronic'));
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);
      await tester.tap(find.text('Apply'));
      await advance(tester, const Duration(seconds: 2));
      expect(find.text('2 genres'), findsOneWidget);
      expect(find.text('Glass Orchard'), findsNothing); // Indie is filtered out
      expect(find.text('Low Tide Letters'), findsOneWidget);
      expect(find.text('Night Transit'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('leaving a tab fades it out before the next one appears', (tester) async {
      await openLibrary(tester);
      expect(find.text('Low Tide Letters'), findsOneWidget);
      await tester.tap(find.widgetWithText(ExpressiveChip, 'Songs'));
      await advance(tester, const Duration(milliseconds: 60));
      expect(find.text('Low Tide Letters'), findsOneWidget, reason: 'old tab is still fading out');
      await advance(tester, const Duration(seconds: 2));
      expect(find.text('Low Tide Letters'), findsNothing);
      await disposeApp(tester);
    });

    testWidgets('the Artists sidebar page counts artists; Playlists tab counts playlists', (tester) async {
      await openLibrary(tester);
      expect(find.widgetWithText(ExpressiveChip, 'Artists'), findsNothing);
      await tester.tap(find.text('Artists').first);
      await advance(tester, const Duration(seconds: 2));
      expect(find.text('12 artists'), findsOneWidget);
      await tester.tap(find.text('Library').first);
      await advance(tester, const Duration(seconds: 2));
      await tester.tap(find.widgetWithText(ExpressiveChip, 'Playlists'));
      await advance(tester, const Duration(seconds: 2));
      expect(find.text('2 playlists'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('a big library loads page by page and the A-Z rail scrolls to the letter', (tester) async {
      final albums = [
        for (var i = 0; i < 300; i++)
          Album(
            id: 'big-$i',
            title: '${String.fromCharCode(65 + i % 26)}lbum ${i.toString().padLeft(3, '0')}',
            artist: 'Artist $i',
            coverArt: 'c$i',
          ),
      ];
      final api = FakeLibraryApi(albums: albums);
      final container = await openLibrary(tester, api: api);
      container.read(librarySortProvider.notifier).set(LibrarySort.name);
      await advance(tester, const Duration(seconds: 3));
      expect(find.text('300 albums'), findsOneWidget);
      // First page 120, then the rest in one more request.
      expect(api.calls.where((c) => c.startsWith('getAlbumList:alphabeticalByName')), ['getAlbumList:alphabeticalByName:0', 'getAlbumList:alphabeticalByName:120']);

      expect(find.text('Nlbum 013'), findsNothing); // far below the fold
      await tester.tap(find.text('N').last);
      await advance(tester, const Duration(seconds: 2));
      final y = tester.getTopLeft(find.text('Nlbum 013')).dy;
      expect(y, inInclusiveRange(100, 700), reason: 'the N section should be on screen');
      await disposeApp(tester);
    });
  });

  group('A-Z jump', () {
    test('finds the first title for a letter, skipping articles like the server', () {
      final titles = ['Abbey Road', 'The Beatles', 'Blue', 'Cosmos', 'The Cure', 'Dune'];
      expect(firstIndexForLetter(titles, 'A'), 0);
      expect(firstIndexForLetter(titles, 'B'), 1); // "The Beatles" files under B
      expect(firstIndexForLetter(titles, 'C'), 3);
      expect(firstIndexForLetter(titles, 'Z'), -1);
      expect(firstIndexForLetter(['1999', '(What) Story'], '#'), 0);
    });
  });

  group('liked songs, playlists and continue listening', () {
    testWidgets('Home has a Surprise me row after Recently added, and no Liked row', (tester) async {
      await pumpApp(tester);
      final added = tester.getTopLeft(find.text('Recently added')).dy;
      final fresh = tester.getTopLeft(find.text('Surprise me')).dy;
      expect(fresh, greaterThan(added));
      expect(find.text('Liked songs'), findsNothing);
      await disposeApp(tester);
    });

    testWidgets('Jump back in has a random, a recently played and a recently added album', (tester) async {
      await pumpApp(tester);
      for (final tag in ['RANDOM', 'RECENTLY PLAYED', 'NEW']) {
        expect(find.text(tag), findsOneWidget, reason: tag);
      }
      await disposeApp(tester);
    });

    testWidgets('Continue listening appears once a queue exists and toggles playback', (tester) async {
      final container = await pumpApp(tester);
      expect(find.text('Continue listening'), findsNothing);
      await container.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
      await advance(tester, const Duration(seconds: 1));
      expect(find.text('Continue listening'), findsOneWidget);
      expect(container.read(playbackProvider).playing, isTrue);
      await tester.tap(find.text('Continue listening'));
      await advance(tester, const Duration(milliseconds: 500));
      expect(container.read(playbackProvider).playing, isFalse);
      await disposeApp(tester);
    });

    testWidgets('the Liked page lists hearted songs and can switch to cards', (tester) async {
      final container = await pumpApp(tester);
      await tester.tap(find.text('Liked').first);
      await advance(tester, const Duration(seconds: 2));
      expect(find.text('1 song'), findsOneWidget);
      expect(find.byType(SongRow), findsOneWidget);
      await tester.tap(find.byTooltip('Show as cards'));
      await advance(tester, const Duration(seconds: 2));
      expect(find.byType(SongRow), findsNothing);
      expect(find.byType(TrackCard), findsOneWidget);
      expect(container.read(likedAsCardsProvider), isTrue);
      await disposeApp(tester);
    });

    testWidgets('Lists shows playlists as cards', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Lists').first);
      await advance(tester, const Duration(seconds: 2));
      expect(find.text('2 playlists'), findsOneWidget);
      expect(find.byType(PlaylistCard), findsNWidgets(2));
      await disposeApp(tester);
    });
  });

  group('shuffle button, playlist page, rail letters', () {
    testWidgets('the shuffle button is on Home and Liked only, and shuffles what the page shows', (tester) async {
      final container = await pumpApp(tester);
      expect(find.text('Shuffle all'), findsOneWidget);
      await tester.tap(find.text('Library').first);
      await advance(tester, const Duration(seconds: 2));
      final fade = find.ancestor(of: find.text('Shuffle all'), matching: find.byType(AnimatedOpacity));
      expect(tester.widget<AnimatedOpacity>(fade.first).opacity, 0);
      await tester.tap(find.text('Liked').first);
      await advance(tester, const Duration(seconds: 2));
      expect(find.text('Shuffle liked'), findsOneWidget);
      await tester.tap(find.text('Shuffle liked'));
      await advance(tester, const Duration(seconds: 1));
      expect(container.read(playbackProvider).queue.map((t) => t.id), ['t-a2']);
      await container.read(playbackProvider.notifier).toggle();
      await disposeApp(tester);
    });

    testWidgets('a playlist card opens the playlist with its songs instead of playing', (tester) async {
      final container = await pumpApp(tester);
      await tester.tap(find.text('Lists').first);
      await advance(tester, const Duration(seconds: 2));
      await tester.tap(find.text('Late Night Drive'));
      await advance(tester, const Duration(seconds: 2));
      expect(container.read(routerProvider).state.uri.path, '/playlist/pl-1');
      expect(container.read(playbackProvider).queue, isEmpty);
      expect(find.text('Shuffle'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('the A-Z rail lists every letter', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Library').first);
      await advance(tester, const Duration(seconds: 2));
      await tester.tap(find.widgetWithText(ExpressiveChip, 'Songs'));
      await advance(tester, const Duration(seconds: 2));
      for (final l in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
        expect(find.bySemanticsLabel('Jump to $l'), findsOneWidget, reason: l);
      }
      await disposeApp(tester);
    });
  });

  group('remembered choices', () {
    testWidgets('the album sort and song sort are saved; the Library tab always opens on Albums', (tester) async {
      final container = await pumpApp(tester);
      container.read(librarySortProvider.notifier).set(LibrarySort.year);
      container.read(librarySongSortProvider.notifier).set(SongSort.album);
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString('library_sort'), 'year');
      expect(prefs.getString('library_song_sort'), 'album');
      container.read(libraryTabProvider.notifier).set(LibraryTab.songs);
      expect(prefs.getString('library_tab'), isNull, reason: 'the tab is not saved between launches (M8)');
      await disposeApp(tester);
    });

    testWidgets('liking a song in the Songs tab hearts it with a pop', (tester) async {
      final container = await pumpApp(tester);
      await tester.tap(find.text('Library').first);
      await advance(tester, const Duration(seconds: 2));
      await tester.tap(find.widgetWithText(ExpressiveChip, 'Songs'));
      await advance(tester, const Duration(seconds: 2));
      final heart = find.byType(HeartButton).first;
      final pop = tester.state<State>(find.descendant(of: heart, matching: find.byType(BurstLayer))).context;
      expect(pop, isNotNull);
      await tester.tap(heart, warnIfMissed: false);
      await advance(tester, const Duration(milliseconds: 150));
      expect(container.read(likedProvider), isNotEmpty);
      expect(find.descendant(of: heart, matching: find.byIcon(Icons.favorite_rounded)), findsOneWidget);
      await advance(tester, const Duration(seconds: 2));
      await disposeApp(tester);
    });
  });
}
