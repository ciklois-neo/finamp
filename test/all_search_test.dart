import 'dart:async';

import 'package:finamp/components/MusicScreen/all_search_view.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/all_search_provider.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SearchRequest request(String query, {SearchCategory category = SearchCategory.albums, int limit = 10}) =>
    (query: query, library: const BaseItemId('music'), category: category, limit: limit, favorites: false);
BaseItemDto item(String id) => BaseItemDto(id: BaseItemId(id), name: id, type: 'MusicAlbum');

class FakeSearch {
  final calls = <({String? term, String? type, BaseItemId? library, int? limit, ArtistType? artist})>[];
  final Map<ArtistType?, List<BaseItemDto>> results;
  FakeSearch(this.results);
  Future<List<BaseItemDto>?> call({
    BaseItemDto? parentItem,
    String? includeItemTypes,
    String? searchTerm,
    bool? recursive,
    ArtistType? artistType,
    bool? isFavorite,
    int? limit,
  }) async {
    calls.add((term: searchTerm, type: includeItemTypes, library: parentItem?.id, limit: limit, artist: artistType));
    return results[artistType] ?? [];
  }
}

Widget screen(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Widget section(String query) => SearchResultSection(request: request(query), itemBuilder: (x) => Text(x.name!));

void main() {
  for (final offline in [false, true]) {
    testWidgets(offline ? 'offline All search never calls the server' : 'empty All search never calls the server', (
      tester,
    ) async {
      final settings = FinampSettings(
        downloadLocations: [],
        downloadLocationsMap: {},
        tabSortBy: {},
        tabSortOrder: {},
        homeScreenConfiguration: DefaultSettings.homeScreenConfiguration,
        gridImageSize: DefaultSettings.gridImageSize,
        homeScreenImageSize: DefaultSettings.homeScreenImageSize,
        deviceId: 'test',
        isOffline: offline,
      );
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          finampSettingsProvider.overrideWith((ref) => Stream.value(settings)),
          FinampUserHelper.finampCurrentUserProvider.overrideWithValue(null),
          allSearchProvider.overrideWith((ref, r) async {
            calls++;
            return const SearchPage([], hasMore: false);
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(finampSettingsProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: screen(AllSearchView(query: offline ? 'etchno' : '   ')),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byType(SearchResultSection), findsNothing);
    });
  }

  test('blank query makes no request', () async {
    final fake = FakeSearch({});
    expect((await searchCategory(request('  '), fake.call)).items, isEmpty);
    expect(fake.calls, isEmpty);
  });

  test('query is trimmed, scoped to the music library, with a lookahead result', () async {
    final fake = FakeSearch({null: List.generate(11, (i) => item('$i'))});
    final page = await searchCategory(request(' etchno '), fake.call);
    expect(page.items.length, 10);
    expect(page.hasMore, isTrue);
    expect(fake.calls.single.term, 'etchno');
    expect(fake.calls.single.library, const BaseItemId('music'));
    expect(fake.calls.single.limit, 11);
  });

  test('performers and album artists are searched and deduplicated', () async {
    final fake = FakeSearch({
      ArtistType.artist: [item('a'), item('shared')],
      ArtistType.albumArtist: [item('shared'), item('b')],
    });
    final page = await searchCategory(request('name', category: SearchCategory.artists), fake.call);
    expect(page.items.map((x) => x.id.raw), ['a', 'shared', 'b']);
    expect(fake.calls.length, 2);
    expect(page.hasMore, isFalse);
  });

  test('all five categories use their correct endpoints', () async {
    final fake = FakeSearch({});
    for (final category in SearchCategory.values) {
      await searchCategory(request('test', category: category), fake.call);
    }
    expect(fake.calls.map((x) => x.type).toSet(), {'MusicAlbum', 'MusicArtist', 'Audio', 'Playlist', 'MusicGenre'});
    // Jellyfin playlists are user-level containers, not children of a music library.
    expect(fake.calls.singleWhere((x) => x.type == 'Playlist').library, isNull);
  });

  testWidgets('a late response to the old query cannot replace the new query', (tester) async {
    final oldResult = Completer<SearchPage>();
    final newResult = Completer<SearchPage>();
    final container = ProviderContainer(
      overrides: [allSearchProvider.overrideWith((ref, r) => r.query == 'old' ? oldResult.future : newResult.future)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: screen(section('old'))));
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: screen(section('new'))));
    newResult.complete(SearchPage([item('new result')], hasMore: false));
    await tester.pumpAndSettle();
    oldResult.complete(SearchPage([item('stale result')], hasMore: false));
    await tester.pumpAndSettle();
    expect(find.text('new result'), findsOneWidget);
    expect(find.text('stale result'), findsNothing);
  });

  testWidgets('error is retryable and does not become an empty result', (tester) async {
    var tries = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allSearchProvider.overrideWith((ref, r) async {
            if (tries++ == 0) throw StateError('unavailable');
            return SearchPage([item('recovered')], hasMore: false);
          }),
        ],
        child: screen(section('etchno')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not search this category.'), findsOneWidget);
    expect(find.text('No search results'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('recovered'), findsOneWidget);
  });

  testWidgets('show more expands only this category and preserves the query', (tester) async {
    final limits = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allSearchProvider.overrideWith((ref, r) async {
            limits.add(r.limit);
            expect(r.query, 'etchno');
            return SearchPage([item('result')], hasMore: r.limit == 10);
          }),
        ],
        child: screen(section('etchno')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(limits, [10, 30]);
    expect(find.text('Show more'), findsNothing);
  });
}
