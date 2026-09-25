import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/NetworkSettingsScreen/server_address_field.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/components/NetworkSettingsScreen/active_network_display.dart';
import 'package:finamp/components/NetworkSettingsScreen/auto_offline_selector.dart';
import 'package:finamp/components/NetworkSettingsScreen/prefer_local_network_address_selector.dart';
import 'package:finamp/components/NetworkSettingsScreen/prefer_local_network_selector.dart';
import 'package:finamp/components/NetworkSettingsScreen/public_address_selector.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

class NetworkSettingsScreen extends StatefulWidget {
  const NetworkSettingsScreen({super.key});
  static const routeName = "/settings/network";

  @override
  State<NetworkSettingsScreen> createState() => _NetworkSettingsScreenState();
}

class _NetworkSettingsScreenState extends State<NetworkSettingsScreen> {
  final publicAddressKey = GlobalKey<ServerAddressFieldState>();
  final localNetworkAddressKey = GlobalKey<ServerAddressFieldState>();
  bool _busy = false;

  Future<void> _save({bool test = false}) async {
    if (_busy) return;
    final fields = [publicAddressKey.currentState, localNetworkAddressKey.currentState];
    final valid = fields.map((field) => field?.validate() ?? false).toList();
    if (valid.contains(false)) return;
    setState(() => _busy = true);
    try {
      for (final field in fields) {
        if (!await field!.commitIfChanged()) return;
      }
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      if (test) {
        final [public, local] = await Future.wait([
          GetIt.instance<JellyfinApiHelper>().pingPublicServer(),
          GetIt.instance<JellyfinApiHelper>().pingLocalServer(),
        ]);
        GlobalSnackbar.message((context) => AppLocalizations.of(context)!.ping("${public}_${local}"));
      } else {
        GlobalSnackbar.message((context) => AppLocalizations.of(context)!.networkSettingsSaved);
      }
    } catch (error) {
      GlobalSnackbar.error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.networkSettingsTitle),
        leading: FinampAppBarBackButton(),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(context, FinampSettingsHelper.resetNetworkSettings),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 200.0),
        child: Column(children: [
          AutoOfflineSelector(),
          Divider(),
          ActiveNetworkDisplay(),
          PublicAddressSelector(fieldKey: publicAddressKey),
          LocalNetworkSelector(),
          LocalNetworkAddressSelector(fieldKey: localNetworkAddressKey),
          SizedBox(height: 32.0),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              CTAMedium(
                text: AppLocalizations.of(context)!.save,
                icon: TablerIcons.device_floppy,
                disabled: _busy,
                onPressed: () => _save(),
              ),
              CTAMedium(
                text: AppLocalizations.of(context)!.testConnectionButtonLabel,
                icon: TablerIcons.plug_connected,
                disabled: _busy,
                onPressed: () => _save(test: true),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}
