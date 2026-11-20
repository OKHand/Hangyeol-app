import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/market/market_setup.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';

class SetupClient extends AppsScriptPlatformClient {
  SetupClient():super(Uri.parse('https://script.google.com/macros/s/catalogue-test/exec'));
  final calls=<String>[];
  Map<String,dynamic>? lastWarm;
  bool dailyWarmEnabled=false;
  @override
  Future<Map<String,dynamic>> call(String action,{Map<String,dynamic>? params,bool authenticated=true}) async {
    calls.add(action);
    if(action=='market.settings'){
      return {
        'keyConfigured':true,
        'version':'v1',
        'marketCode':'110001',
        'allowPlainHttp':false,
        'dailyWarmEnabled':dailyWarmEnabled,
        'warmLastAt':'2026-11-19T23:02:00Z',
        'warmLastCount':11,
      };
    }
    if(action=='market.warm'){
      lastWarm=params;
      dailyWarmEnabled=params?['enabled']==true;
      return {
        'keyConfigured':true,
        'version':'v1',
        'marketCode':'110001',
        'allowPlainHttp':false,
        'dailyWarmEnabled':dailyWarmEnabled,
        'warmLastAt':'2026-11-19T23:02:00Z',
        'warmLastCount':11,
      };
    }
    throw StateError(action);
  }
}

void main(){
  setUp(MarketPreferences.reset);

  testWidgets('admin setup displays clean sections without legacy tomato discovery dummy and toggles daily warm', (tester) async {
    tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);
    addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);
    final client=SetupClient()..token='a'*64;addTearDown(client.close);

    bool? poppedResult;
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>Scaffold(
      body:Center(child:ElevatedButton(
        onPressed:()async{
          poppedResult=await Navigator.of(context).push<bool>(MaterialPageRoute(builder:(_)=>MarketSetupPage(client:client,canManage:true)));
        },
        child:const Text('open'),
      )),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(client.calls,['market.settings']);
    expect(find.byKey(const Key('market-pref-market')),findsOneWidget);
    expect(find.byKey(const Key('market-pref-default-product')),findsOneWidget);
    expect(find.byKey(const Key('market-pref-days-7')),findsOneWidget);
    expect(find.byKey(const Key('market-pref-days-14')),findsOneWidget);
    expect(find.byKey(const Key('market-pref-days-21')),findsOneWidget);
    expect(find.byKey(const Key('market-pref-unit-kg')),findsOneWidget);
    expect(find.byKey(const Key('market-pref-unit-pkg')),findsOneWidget);
    expect(find.byKey(const Key('market-pref-auto-grades')),findsOneWidget);
    expect(find.byKey(const Key('market-pref-monthly-trend')),findsOneWidget);
    expect(find.byKey(const Key('market-daily-warm-switch')),findsOneWidget);
    expect(find.text('API 연결됨'),findsOneWidget);
    expect(find.textContaining('11.20 08:02'),findsOneWidget);

    // Legacy two-tomato dummy UI is completely removed
    expect(find.byKey(const Key('market-setup-save')),findsNothing);
    expect(find.byKey(const Key('market-discover')),findsNothing);
    expect(find.text('공식 코드에서 품목 찾기'),findsNothing);
    expect(find.textContaining('찰토마토에 연결할 실제 분류'),findsNothing);
    expect(find.textContaining('대추방울토마토에 연결할 실제 분류'),findsNothing);

    await tester.ensureVisible(find.byKey(const Key('market-daily-warm-switch')));
    await tester.tap(find.byKey(const Key('market-daily-warm-switch')));
    await tester.pumpAndSettle();
    expect(client.lastWarm?['enabled'],isTrue);
    expect(client.calls,['market.settings','market.warm']);

    await tester.ensureVisible(find.byKey(const Key('market-pref-days-21')));
    await tester.tap(find.byKey(const Key('market-pref-days-21')));
    await tester.tap(find.byKey(const Key('market-prefs-save-button')));
    await tester.pumpAndSettle();
    expect(poppedResult,isTrue);
    expect(MarketPreferences.current.trendDays,21);
    expect(tester.takeException(),isNull);
  });

  testWidgets('non-admin hides server warm card and makes zero server requests', (tester) async {
    tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(720,900);
    addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);
    final client=SetupClient()..token='a'*64;addTearDown(client.close);

    await tester.pumpWidget(MaterialApp(home:MarketSetupPage(client:client,canManage:false)));
    await tester.pumpAndSettle();

    expect(client.calls,isEmpty);
    expect(find.byKey(const Key('market-daily-warm-switch')),findsNothing);
    expect(find.byKey(const Key('market-pref-market')),findsOneWidget);
    expect(find.byKey(const Key('market-prefs-save-button')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
