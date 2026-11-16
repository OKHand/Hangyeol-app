import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/market/market_prices.dart';
import 'package:hangyeol_platform/src/market/market_setup.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';

class MarketClient extends AppsScriptPlatformClient {
  MarketClient():super(Uri.parse('https://script.google.com/macros/s/market-test/exec'));
  final requests=<Map<String,dynamic>>[];
  @override
  Future<Map<String,dynamic>> call(String action,{Map<String,dynamic>? params,bool authenticated=true}) async {
    expect(action,'market.prices');requests.add(params!);
    throw PlatformAuthFailure('MARKET_SETUP_REQUIRED','실제 API 연결 확인이 필요합니다.');
  }
}

class XmlQuoteClient extends AppsScriptPlatformClient {
  XmlQuoteClient({this.empty=false}):super(Uri.parse('https://script.google.com/macros/s/xml-price-test/exec'));
  final bool empty;
  @override
  Future<Map<String,dynamic>> call(String action,{Map<String,dynamic>? params,bool authenticated=true}) async=>{
    'sample':false,'product':params!['product'],'date':params['date'],'source':'XML 모의 공급처','priceBasis':'unconfirmed','truncated':true,'fetchedAt':'2026-11-11T00:00:00Z',
    'quotes':empty?<Map<String,dynamic>>[]:[{'id':'xml-1','productName':'일반토마토','market':'모의 시장','grade':'등급 미제공','package':'5kg 상자','price':15000,'priceBasis':'unconfirmed','quantity':43,'quantityUnitConfirmed':false,'date':params['date'],'company':'모의 법인','auctionTime':'2026-11-11 09:00:00'}],
  };
}

void phone(WidgetTester tester){tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);}
void main(){
  setUp(MarketPreferences.reset);

  testWidgets('offline mode uses local demo quotes and allows switching crops and markets',(tester) async {
    phone(tester);await tester.pumpWidget(const MaterialApp(home:MarketPricesPage()));await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-live')),findsNothing);expect(find.byKey(const Key('market-sample')),findsNothing);expect(find.byKey(const Key('market-sample-banner')),findsNothing);
    expect(find.text('14,000원 / 5kg 상자'),findsOneWidget);
    await tester.tap(find.byKey(const Key('market-product-date-cherry-tomato')));await tester.pumpAndSettle();expect(find.text('18,000원 / 3kg 상자'),findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));await tester.pumpAndSettle();await tester.tap(find.text('예시 도매시장 B').last);await tester.pumpAndSettle();
    expect(find.textContaining('표시 1건'),findsOneWidget);expect(tester.takeException(),isNull);
  });
  testWidgets('online mode queries live prices only without a live/sample toggle',(tester) async {
    phone(tester);final client=MarketClient()..token='a'*64;addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(home:MarketPricesPage(client:client)));await tester.pumpAndSettle();
    expect(client.requests,hasLength(1));expect(client.requests.single['product'],'general-tomato');expect(find.text('실제 API 연결 확인이 필요합니다.'),findsOneWidget);
    expect(find.byKey(const Key('market-live')),findsNothing);expect(find.byKey(const Key('market-sample')),findsNothing);expect(find.byKey(const Key('market-sample-banner')),findsNothing);expect(find.textContaining('14,000원'),findsNothing);
    expect(tester.takeException(),isNull);
  });
  testWidgets('XML provider prices with unverified unit basis remain clearly labeled without a kg calculation',(tester) async {
    phone(tester);final client=XmlQuoteClient()..token='a'*64;addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(home:MarketPricesPage(client:client)));await tester.pumpAndSettle();
    expect(find.text('15,000원 (제공가격)'),findsOneWidget);expect(find.textContaining('등급 미제공'),findsOneWidget);expect(find.textContaining('43 (단위 미확인)'),findsOneWidget);expect(find.textContaining('kg당'),findsNothing);expect(tester.takeException(),isNull);
  });
  testWidgets('a partial empty result is not described as a whole trading day with no data',(tester) async {
    phone(tester);final client=XmlQuoteClient(empty:true)..token='a'*64;addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(home:MarketPricesPage(client:client)));await tester.pumpAndSettle();
    expect(find.textContaining('전체 거래에 자료가 없다는 의미는 아닙니다.'),findsOneWidget);expect(find.textContaining('휴장·수집 지연'),findsNothing);expect(tester.takeException(),isNull);
  });
  testWidgets('quick presets follow the exact requested order and item-code catalogue selection queries any crop',(tester) async {
    phone(tester);final client=XmlQuoteClient()..token='a'*64;addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(home:MarketPricesPage(client:client)));await tester.pumpAndSettle();
    expect(marketOrderedProducts.keys.toList(),['general-tomato','chal-tomato','date-cherry-tomato','paprika','eggplant','red-pepper','green-pepper','cucumber-baekdadagi','onion','cabbage','broccoli']);
    expect(marketOrderedProducts.values.toList(),['일반토마토','찰토마토','대추방울','파프리카','가지','홍고추','풋고추','백다다기','양파','양배추','브로콜리']);
    for(final key in marketOrderedProducts.keys){
      expect(find.byKey(Key('market-product-$key')),findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('market-product-paprika')));await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-dashboard-card')),findsOneWidget);
    expect(find.byKey(const Key('market-avg-price-card')),findsOneWidget);
    expect(find.byKey(const Key('market-total-volume-card')),findsOneWidget);
    expect(find.byKey(const Key('market-trend-chart')),findsOneWidget);
    expect(find.textContaining('일별 시세 추이'),findsOneWidget);
    await tester.tap(find.byKey(const Key('market-catalogue-panel')));await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('market-item-search')),'취청');await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('market-code-09:01:01')));await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-product-custom')),findsOneWidget);expect(tester.takeException(),isNull);
  });

  testWidgets('monthly KAMIS trend renders directly beneath the daily trend chart',(tester) async {
    phone(tester);
    final client=_MonthlyTrendClient()..token='a'*64;
    addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(home:MarketPricesPage(client:client)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-trend-chart')),findsOneWidget);
    expect(find.byKey(const Key('market-monthly-trend-chart')),findsOneWidget);
    expect(find.textContaining('월별 시세 추이'),findsOneWidget);
    expect(find.textContaining('KAMIS 서울 도매'),findsOneWidget);
    expect(find.descendant(of:find.byKey(const Key('market-monthly-trend-chart')),matching:find.textContaining('단위 : 원/kg')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}

class _MonthlyTrendClient extends AppsScriptPlatformClient {
  _MonthlyTrendClient():super(Uri.parse('https://script.google.com/macros/s/monthly-test/exec'));
  @override
  Future<Map<String,dynamic>> call(String action,{Map<String,dynamic>? params,bool authenticated=true}) async {
    if(params?['monthlyTrend']==true){
      return {
        'supported':true,
        'unit':'1kg',
        'unitLabel':'원/kg',
        'isPerKg':true,
        'regionName':'서울',
        'cropLabel':'토마토',
        'points':[
          {'month':'2026-09','label':'26.09','avgPrice':4816},
          {'month':'2026-10','label':'26.10','avgPrice':3877},
          {'month':'2026-11','label':'26.11','avgPrice':3076},
        ],
      };
    }
    if(params?['trendBatch']==true){
      return {'points':[{'date':'2026-11-15','label':'11.15','avgPricePerKg':3100}]};
    }
    return {
      'sample':false,'product':params!['product'],'date':params['date'],'source':'테스트 시세','priceBasis':'per-package','truncated':false,'fetchedAt':'2026-11-16T00:00:00Z',
      'trendPending':true,
      'quotes':[{'id':'m-1','productName':'일반토마토','market':'서울가락','grade':'특','package':'5kg 상자','price':16000,'priceBasis':'per-package','quantity':10,'weightKg':5,'pricePerKg':3200,'date':params['date'],'company':'한국청과','auctionTime':'2026-11-16 08:00:00'}],
    };
  }
}
