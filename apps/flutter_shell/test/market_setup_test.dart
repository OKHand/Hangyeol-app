import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/market/market_setup.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';

class SetupClient extends AppsScriptPlatformClient {
  SetupClient():super(Uri.parse('https://script.google.com/macros/s/catalogue-test/exec'));
  final calls=<String>[];
  Map<String,dynamic>? saved;
  @override
  Future<Map<String,dynamic>> call(String action,{Map<String,dynamic>? params,bool authenticated=true}) async {
    calls.add(action);
    if(action=='market.settings'){return {'keyConfigured':true,'version':'v1','marketCode':'110001','allowPlainHttp':false};}
    if(action=='market.catalogue'){expect(params!['allowPlainHttp'],isTrue);expect(params.containsKey('date'),isFalse);return {'items':[
      {'id':'98:97:96','receipt':'a'*64,'category':'토마토','variety':'합성 찰토마토','eligible':['chal-tomato']},
      {'id':'98:97:95','receipt':'b'*64,'category':'방울토마토','variety':'합성 대추방울토마토','eligible':['date-cherry-tomato']},
      {'id':'98:97:94','receipt':'c'*64,'category':'토마토','variety':'일반 토마토','eligible':<String>[]},
    ],'scanned':1000,'nextStart':1001};}
    if(action=='market.configure'){saved=params;return {'configured':true};}
    throw StateError(action);
  }
}
void main(){
  setUp(MarketPreferences.reset);

  testWidgets('admin setup reads the official code API without a trade date or displaying the server key',(tester) async {
    tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);
    final client=SetupClient()..token='a'*64;addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(home:MarketSetupPage(client:client)));await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-pref-market')),findsOneWidget);
    expect(find.byKey(const Key('market-pref-default-product')),findsOneWidget);
    expect(find.byKey(const Key('market-pref-days-7')),findsOneWidget);
    expect(find.byKey(const Key('market-pref-days-14')),findsOneWidget);
    expect(find.byKey(const Key('market-pref-days-21')),findsOneWidget);
    expect(find.byKey(const Key('market-pref-monthly-trend')),findsOneWidget);
    final discover=find.byKey(const Key('market-discover'));expect(tester.widget<FilledButton>(discover).onPressed,isNull);expect(client.calls,['market.settings']);
    final httpSwitch=find.byKey(const Key('market-setup-http'));await tester.ensureVisible(httpSwitch);await tester.tap(httpSwitch);await tester.pumpAndSettle();await tester.ensureVisible(discover);await tester.tap(discover);await tester.pumpAndSettle();
    expect(client.calls,['market.settings','market.catalogue']);expect(find.text('공식 코드에서 품목 찾기'),findsNothing);expect(find.text('다음 코드에서 품목 찾기'),findsOneWidget);expect(find.byKey(const Key('market-setup-date')),findsNothing);
    final chal=find.byKey(const ValueKey('market-choice-chal-tomato-98:97:96')),cherry=find.byKey(const ValueKey('market-choice-date-cherry-tomato-98:97:95'));
    await tester.ensureVisible(chal);await tester.tap(chal);await tester.pumpAndSettle();await tester.ensureVisible(cherry);await tester.tap(cherry);await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('market-choice-chal-tomato-98:97:94')),findsNothing);
    final save=find.byKey(const Key('market-setup-save'));await tester.ensureVisible(save);await tester.tap(save);await tester.pumpAndSettle();
    expect(client.saved!['receipts'],{'chal-tomato':'a'*64,'date-cherry-tomato':'b'*64});expect(client.saved!.containsKey('apiKey'),isFalse);expect(tester.takeException(),isNull);
  });
}
