import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/serverless/app.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';

class _Vault implements SessionVault {
  @override
  Future<String?> read(String key) async => 'a' * 64;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _Client extends AppsScriptPlatformClient {
  _Client() : super(Uri.parse('https://script.google.com/macros/s/nav-test/exec'));
  int marketCalls = 0;
  @override
  Future<Map<String, dynamic>> me() async => {
    'email': 'viewer@example.com', 'role': 'viewer',
    'permissions': ['erp.read', 'photos.read'],
  };
  @override
  Future<Map<String, List<String>>> suggestions() async => {};
  @override
  Future<Map<String, dynamic>> call(String action, {Map<String, dynamic>? params, bool authenticated = true}) async {
    if (action != 'market.prices') throw StateError('Unexpected request: $action');
    marketCalls++;
    return {'sample': false, 'product': params!['product'], 'date': params['date'],
      'quotes': <Map<String, dynamic>>[], 'source': 'Test provider', 'fetchedAt': ''};
  }
}

void main() {
  testWidgets('Market tab follows Photos, loads lazily and preserves Settings navigation', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final client = _Client()..token = 'a' * 64;
    addTearDown(client.close);
    await tester.pumpWidget(ServerlessApp(apiUrl: client.url.toString(), client: client, vault: _Vault()));
    await tester.pumpAndSettle();
    final destinations = tester.widgetList<NavigationDestination>(find.byType(NavigationDestination));
    expect(destinations.map((d) => d.label), ['ERP', '작황 사진', '농산물 시세', '설정']);
    expect(client.marketCalls, 0);
    expect(find.byTooltip('농산물 경매 시세'), findsNothing);
    await tester.tap(find.byKey(const Key('open-market-prices')));
    await tester.pumpAndSettle();
    expect(client.marketCalls, 1);
    expect(find.byKey(const Key('market-live')), findsNothing);
    expect(find.byKey(const Key('market-open-setup')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('설정')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-app-update')), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-market-prices')));
    await tester.pumpAndSettle();
    expect(client.marketCalls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
