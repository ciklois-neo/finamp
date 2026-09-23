import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';
import 'jellyfin_api_helper.dart';
import 'finamp_user_helper.dart';

enum SearchCategory { albums, artists, tracks, playlists, genres }

typedef SearchRequest = ({String query, BaseItemId? library, SearchCategory category, int limit, bool favorites});
typedef SearchFetch =
    Future<List<BaseItemDto>?> Function({
      BaseItemDto? parentItem,
      String? includeItemTypes,
      String? searchTerm,
      bool? recursive,
      ArtistType? artistType,
      bool? isFavorite,
      int? limit,
    });

class SearchPage {
  const SearchPage(this.items, {required this.hasMore});
  final List<BaseItemDto> items;
  final bool hasMore;
}

/// Separate requests keep a busy category from consuming every result slot.
/// Request one extra result so a capped preview is never presented as complete.
Future<SearchPage> searchCategory(SearchRequest request, SearchFetch fetch) async {
  final query = request.query.trim();
  if (query.isEmpty) return const SearchPage([], hasMore: false);
  final type = switch (request.category) {
    SearchCategory.albums => 'MusicAlbum',
    SearchCategory.artists => 'MusicArtist',
    SearchCategory.tracks => 'Audio',
    SearchCategory.playlists => 'Playlist',
    SearchCategory.genres => 'MusicGenre',
  };
  Future<List<BaseItemDto>?> load([ArtistType? artistType]) => fetch(
    parentItem: request.library == null || request.category == SearchCategory.playlists
        ? null
        : BaseItemDto(id: request.library!, type: 'CollectionFolder'),
    includeItemTypes: type,
    searchTerm: query,
    recursive: true,
    artistType: artistType,
    isFavorite: request.favorites ? true : null,
    limit: request.limit + 1,
  );
  final batches = await Future.wait(
    request.category == SearchCategory.artists ? [load(ArtistType.artist), load(ArtistType.albumArtist)] : [load()],
  );
  final unique = <BaseItemId, BaseItemDto>{};
  for (final batch in batches) {
    for (final item in batch ?? <BaseItemDto>[]) {
      unique.putIfAbsent(item.id, () => item);
    }
  }
  final items = unique.values.toList();
  return SearchPage(
    items.take(request.limit).toList(),
    hasMore: items.length > request.limit || batches.any((b) => (b?.length ?? 0) > request.limit),
  );
}

final allSearchProvider = FutureProvider.autoDispose.family<SearchPage, SearchRequest>((ref, request) {
  ref.watch(FinampUserHelper.finampCurrentUserProvider);
  return searchCategory(request, GetIt.instance<JellyfinApiHelper>().getItems);
});
