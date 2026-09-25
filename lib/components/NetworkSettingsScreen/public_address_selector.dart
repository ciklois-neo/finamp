import 'package:finamp/components/NetworkSettingsScreen/server_address_field.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/network_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

class PublicAddressSelector extends ConsumerWidget {
  const PublicAddressSelector({super.key, this.fieldKey});
  final GlobalKey<ServerAddressFieldState>? fieldKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    title: Text(AppLocalizations.of(context)!.preferLocalNetworkPublicAddressSettingTitle),
    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(AppLocalizations.of(context)!.preferLocalNetworkPublicAddressSettingDescription),
      ServerAddressField(
        key: fieldKey,
        address: ref.watch(FinampUserHelper.finampCurrentUserProvider)?.publicAddress ?? '',
        onCommit: (address) async {
          GetIt.instance<FinampUserHelper>().currentUser?.update(newPublicAddress: address);
          await changeTargetUrl();
        },
      ),
    ]),
  );
}
