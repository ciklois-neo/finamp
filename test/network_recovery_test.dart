import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

class FakeApi implements JellyfinApiHelper {
  int calls = 0;
  @override
  Future<BaseItemDto> getItemById(BaseItemId id) async {
    calls++;
    if (calls == 1) throw Exception('old address is unreachable');
    return BaseItemDto(id: id, name: 'Music');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UnusedDownloads implements DownloadsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('failed library lookup reloads after active server address changes', () async {
    final api = FakeApi();
    GetIt.instance.registerSingleton<JellyfinApiHelper>(api);
    GetIt.instance.registerSingleton<DownloadsService>(UnusedDownloads());
    addTearDown(GetIt.instance.reset);
    var user = FinampUser(
      id: 'test',
      publicAddress: 'http://old',
      localAddress: '',
      preferLocalNetwork: false,
      isLocal: false,
      accessToken: 'test',
      serverId: 'test',
    );
    final settings = FinampSettings(
      downloadLocations: [],
      downloadLocationsMap: {},
      tabSortBy: {},
      tabSortOrder: {},
      homeScreenConfiguration: DefaultSettings.homeScreenConfiguration,
      gridImageSize: DefaultSettings.gridImageSize,
      homeScreenImageSize: DefaultSettings.homeScreenImageSize,
      deviceId: 'test',
      isOffline: false,
    );
    final container = ProviderContainer(
      overrides: [
        finampSettingsProvider.overrideWith((ref) => Stream.value(settings)),
        FinampUserHelper.finampCurrentUserProvider.overrideWith((ref) => user),
      ],
    );
    addTearDown(container.dispose);
    await container.read(finampSettingsProvider.future);
    final provider = itemByIdProvider(const BaseItemId('library'));
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await expectLater(container.read(provider.future), throwsException);
    expect(api.calls, 1);
    // Isar invalidates the cached object and returns a fresh user on a write.
    user = FinampUser(
      id: 'test',
      publicAddress: 'http://new',
      localAddress: '',
      preferLocalNetwork: false,
      isLocal: false,
      accessToken: 'test',
      serverId: 'test',
    );
    container.invalidate(FinampUserHelper.finampCurrentUserProvider);
    await container.pump();
    expect((await container.read(provider.future))?.name, 'Music');
    expect(api.calls, 2);
  });
}
