# All search

Searching from the main music screen selects a temporary **All** tab. It replaces
Home during search, including when the user has hidden Home. Closing search
restores the original tab and normal navigation. Existing category tabs use the
same query for focused searching. Searches within a configured single-category
home section retain that section's scope.

The combined view shows albums, artists (performers and album artists, merged by
ID), tracks, playlists and genres. Categories are queried independently so one
category cannot consume all result slots. Each initially shows up to ten results;
Show more increases that category's window by twenty. A lookahead result indicates
whether more are available. A failed category has its own retry button. Track taps
use the normal playback tile; other items use normal navigation and menus.

Queries are trimmed and debounced for 350 ms by the owning screen. Clearing or
leaving search cancels the timer. Async requests are keyed by query, library,
category, limit and favorites; a late response to an old query cannot replace the
current results. Account changes invalidate the search provider. This isolates
late responses but does not abort an HTTP request already sent to Jellyfin.

Albums, artists, tracks and genres use the selected library. Playlists use the
existing app's user-level playlist scope because they are not library children.
The favorites filter is preserved. Matching uses Jellyfin's existing search
semantics; this does not introduce full-text searching of lyrics or arbitrary tags.

The combined view is currently online-only. Offline mode displays an explicit
message and makes no search request; the existing category tabs still provide
their existing downloaded-item search. Very large result sets use expanding
prefix requests rather than offset paging, including deduplicated artist results.

## Validation

- Unit tests: empty query, whitespace, library scope, category endpoints, artist
  deduplication, and lookahead limits.
- Widget tests: empty/offline states make no requests, stale responses, retry,
  and per-category Show more.
- Run `flutter test test/all_search_test.dart` and the existing test suite.
- Device checklist: search from Home and Tracks; search with Home disabled;
  clear/back restores the previous tab; matching album opens; a track plays;
  switch between All and a category without retyping; no-result and offline states.

This development branch builds on the discovery-feedback branch so the personal
debug build retains its existing discovery fixes. The All-search commit is kept
separate for review or cherry-picking upstream. No credentials or server-specific
configuration are required by the change.

### Initial validation result

- All 33 automated tests pass (9 new search tests and 24 discovery regressions).
- Focused Flutter analysis has no errors or warnings; four pre-existing
  `withOpacity` deprecation infos remain in the shared header.
- Android arm64 debug APK built and installed as an update to the existing debug
  package on Android 16, preserving login/settings. Official app remains separate.
- Real-server device checks passed: combined album/artist search, opening a
  16-track album with artwork, track search and playback with advancing position,
  switching to Tracks without retyping, starting search from Tracks selects All,
  and close/back restores the pre-search tab. Playback was paused after testing.
- Offline/empty query, stale response, retry and Show more are covered by automated
  tests. Hidden-Home behavior still needs a full device settings round trip.
