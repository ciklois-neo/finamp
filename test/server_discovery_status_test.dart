import 'package:finamp/components/LoginScreen/server_discovery_status.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget screen({bool hasServers = false, Key? statusKey}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: ServerDiscoveryStatus(key: statusKey, hasServers: hasServers),
  ),
);

void main() {
  testWidgets('no replies gives manual connection guidance after the initial wait', (tester) async {
    await tester.pumpWidget(screen());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(find.textContaining('No servers found automatically yet'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Enter its address above'), findsOneWidget);
  });

  testWidgets('a late server replaces the empty state without restarting discovery', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pump(const Duration(seconds: 8));
    expect(find.textContaining('No servers found automatically yet'), findsOneWidget);
    await tester.pumpWidget(screen(hasServers: true));
    expect(find.textContaining('No servers found automatically yet'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a server found during the initial wait never shows the empty hint', (tester) async {
    await tester.pumpWidget(screen(hasServers: true));
    await tester.pump(const Duration(seconds: 8));
    expect(find.textContaining('No servers found automatically yet'), findsNothing);
  });

  testWidgets('leaving the screen cancels the pending update', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fresh discovery session gets a fresh initial wait', (tester) async {
    await tester.pumpWidget(screen(statusKey: const ValueKey(1)));
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpWidget(screen(statusKey: const ValueKey(2)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('No servers found automatically yet'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
