import 'package:finamp/components/NetworkSettingsScreen/server_address_field.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget screen(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  test('server address validation accepts base paths and rejects unusable URLs', () {
    for (final address in ['http://server:8096', 'https://music.example/jellyfin', ' http://[::1]:8096/ ']) {
      expect(isValidServerAddress(address), isTrue, reason: address);
    }
    for (final address in ['', 'server:8096', 'httpfoo', 'http://', 'ftp://server', 'http://a b',
      'http://server:99999', 'https://user:pass@server', 'https://server?token=secret', 'https://server/#home']) {
      expect(isValidServerAddress(address), isFalse, reason: address);
    }
  });

  testWidgets('Save commits edited address without submitting keyboard', (tester) async {
    final key = GlobalKey<ServerAddressFieldState>();
    final saved = <String>[];
    await tester.pumpWidget(screen(Column(children: [
      ServerAddressField(key: key, address: 'http://old:8096', onCommit: (s) async { saved.add(s); }),
      TextButton(onPressed: () => key.currentState!.commitIfChanged(), child: const Text('Save')),
    ])));
    await tester.enterText(find.byType(TextFormField), ' http://remote:8096 ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, ['http://remote:8096']);
    expect(await key.currentState!.commitIfChanged(), isTrue);
    expect(saved, hasLength(1));
  });

  testWidgets('focus loss persists a public address', (tester) async {
    final saved = <String>[];
    await tester.pumpWidget(screen(Column(children: [
      ServerAddressField(address: 'http://old', onCommit: (s) async { saved.add(s); }),
      const TextField(key: Key('other')),
    ])));
    await tester.enterText(find.byType(TextFormField), 'http://remote');
    await tester.tap(find.byKey(const Key('other')));
    await tester.pumpAndSettle();
    expect(saved, ['http://remote']);
  });

  testWidgets('invalid edit stays uncommitted and can be corrected', (tester) async {
    final key = GlobalKey<ServerAddressFieldState>();
    final saved = <String>[];
    await tester.pumpWidget(screen(ServerAddressField(key: key, address: 'http://old', onCommit: (s) async { saved.add(s); })));
    await tester.enterText(find.byType(TextFormField), 'http://');
    expect(await key.currentState!.commitIfChanged(), isFalse);
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(find.textContaining('Enter a valid'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'http://fixed');
    expect(await key.currentState!.commitIfChanged(), isTrue);
    expect(saved, ['http://fixed']);
  });

  testWidgets('disabled local address does not block saving the public address', (tester) async {
    final key = GlobalKey<ServerAddressFieldState>();
    await tester.pumpWidget(screen(ServerAddressField(key: key, address: '', enabled: false, onCommit: (_) async { fail('disabled field saved'); })));
    expect(await key.currentState!.commitIfChanged(), isTrue);
  });

  testWidgets('reset updates field but unrelated rebuild preserves pending edit', (tester) async {
    final key = GlobalKey<ServerAddressFieldState>();
    Widget field(String address) => screen(ServerAddressField(key: key, address: address, onCommit: (_) async {}));
    await tester.pumpWidget(field('http://old'));
    await tester.pumpWidget(field('http://reset'));
    expect(find.text('http://reset'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'http://pending');
    await tester.pumpWidget(field('http://reset'));
    expect(find.text('http://pending'), findsOneWidget);
  });
}
