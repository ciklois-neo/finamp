import 'package:finamp/components/NetworkSettingsScreen/server_address_field.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/network_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

class LocalNetworkAddressSelector extends ConsumerWidget {
  const LocalNetworkAddressSelector({super.key, this.fieldKey});
  final GlobalKey<ServerAddressFieldState>? fieldKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(FinampUserHelper.finampCurrentUserProvider);
    final enabled = user?.preferLocalNetwork ?? DefaultSettings.preferLocalNetwork;
    return ListTile(
      enabled: enabled,
      title: Text(AppLocalizations.of(context)!.preferLocalNetworkTargetAddressLocalSettingTitle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.preferLocalNetworkTargetAddressLocalSettingDescription),
          ServerAddressField(
            key: fieldKey,
            enabled: enabled,
            address: user?.localAddress ?? DefaultSettings.localNetworkAddress,
            onCommit: (address) async {
              GetIt.instance<FinampUserHelper>().currentUser?.update(newLocalAddress: address);
              await changeTargetUrl();
            },
          ),
        ],
      ),
    );
  }
}
