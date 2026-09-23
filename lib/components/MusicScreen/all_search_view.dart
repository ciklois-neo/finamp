import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../extensions/localizations.dart';
import '../../l10n/app_localizations.dart';
import '../../models/jellyfin_models.dart';
import '../../models/finamp_models.dart';
import '../../models/music_models.dart';
import '../../services/all_search_provider.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/finamp_user_helper.dart';
import '../AlbumScreen/track_list_tile.dart';
import 'item_wrapper.dart';

class AllSearchView extends ConsumerWidget {
  const AllSearchView({super.key, required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(finampSettingsProvider.isOffline)) {
      // Existing category tabs continue to provide their downloaded-item search.
      return Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(context.l10n.searchNotAvailibleWhileOffline)),
      );
    }
    final user = ref.watch(FinampUserHelper.finampCurrentUserProvider);
    final library = user?.currentView?.id;
    final favorites = ref.watch(finampSettingsProvider.onlyShowFavorites);
    if (query.trim().isEmpty) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(context.l10n.searchEverythingHint)),
      );
    }
    return ListView(
      key: ValueKey((query, user?.id, library, favorites)),
      padding: const EdgeInsets.only(bottom: 160),
      children: [
        for (final category in SearchCategory.values)
          SearchResultSection(
            key: ValueKey((query, user?.id, library, favorites, category)),
            request: (query: query, library: library, category: category, limit: 10, favorites: favorites),
          ),
      ],
    );
  }
}

/// Public to test asynchronous result changes without initializing audio playback.
class SearchResultSection extends ConsumerStatefulWidget {
  const SearchResultSection({super.key, required this.request, this.itemBuilder});
  final SearchRequest request;
  final Widget Function(BaseItemDto)? itemBuilder;

  @override
  ConsumerState<SearchResultSection> createState() => _SearchResultSectionState();
}

class _SearchResultSectionState extends ConsumerState<SearchResultSection> {
  late int limit = widget.request.limit;

  @override
  void didUpdateWidget(covariant SearchResultSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request != widget.request) limit = widget.request.limit;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final request = (query: r.query, library: r.library, category: r.category, limit: limit, favorites: r.favorites);
    final provider = allSearchProvider(request);
    final result = ref.watch(provider);
    final l10n = AppLocalizations.of(context)!;
    final title = switch (r.category) {
      SearchCategory.albums => l10n.albums,
      SearchCategory.artists => l10n.artists,
      SearchCategory.tracks => l10n.tracks,
      SearchCategory.playlists => l10n.playlists,
      SearchCategory.genres => l10n.genres,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        ),
        result.when(
          skipLoadingOnRefresh: false,
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(l10n.searchGroupError),
                TextButton(onPressed: () => ref.invalidate(provider), child: Text(l10n.retry)),
              ],
            ),
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noSearchResults));
            }
            return Column(
              children: [
                for (var i = 0; i < page.items.length; i++)
                  widget.itemBuilder?.call(page.items[i]) ??
                      (r.category == SearchCategory.tracks
                          ? TrackListTile(
                              key: ValueKey(page.items[i].id),
                              item: page.items[i],
                              index: i,
                              parentPlayable: PrecalculatedPlayable(
                                source: QueueItemSource.fromBaseItem(page.items[i]),
                                tracks: page.items,
                              ),
                            )
                          : ItemWrapper(key: ValueKey(page.items[i].id), item: page.items[i])),
                if (page.hasMore)
                  TextButton(onPressed: () => setState(() => limit += 20), child: Text(l10n.searchMore)),
              ],
            );
          },
        ),
      ],
    );
  }
}
