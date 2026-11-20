import 'dart:async';
import 'dart:io';
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

  addAdditionalMarketCacheTests();
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

class _StagedMarketClient extends AppsScriptPlatformClient {
  _StagedMarketClient({this.holdQuotes}) : super(Uri.parse('https://script.google.com/macros/s/staged-market/exec'));
  Completer<void>? holdQuotes;
  final requests = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> call(String action, {Map<String, dynamic>? params, bool authenticated = true}) async {
    expect(action, 'market.prices');
    final p = Map<String, dynamic>.from(params ?? {});
    requests.add(p);
    final product = p['product'] as String;
    final date = p['date'] as String;
    if (p['monthlyTrend'] == true) {
      return {
        'supported': true,
        'unit': '1kg',
        'unitLabel': '원/kg',
        'isPerKg': true,
        'regionName': '서울',
        'cropLabel': marketOrderedProducts[product] ?? product,
        'points': [
          {'month': '2026-10', 'label': '26.10', 'avgPrice': 3600},
          {'month': '2026-11', 'label': '26.11', 'avgPrice': 3800},
        ],
      };
    }
    if (p['trendBatch'] == true) {
      final dates = List<String>.from(p['dates'] as List? ?? []);
      return {
        'points': [
          for (var i = 0; i < dates.length; i++)
            {'date': dates[i], 'label': dates[i].substring(5).replaceAll('-', '.'), 'avgPricePerKg': 3500 + i * 50, 'avgPackagePrice': 17500, 'totalWeightKg': 100},
        ],
      };
    }
    if (p['summaryOnly'] == true) {
      return {
        'sample': false,
        'product': product,
        'productName': marketOrderedProducts[product] ?? product,
        'large': '08',
        'mid': '03',
        'small': '01',
        'date': date,
        'quotes': <Map<String, dynamic>>[],
        'summary': {
          'avgPricePerKg': product == 'paprika' ? 5200 : 4100,
          'totalWeightKg': 3200,
          'avgPackagePrice': 20500,
          'totalQuantity': 640,
          'groups': [
            {'label': '[특] 5kg 상자', 'avgPricePerKg': 4400, 'avgPrice': 22000, 'totalWeightKg': 2000, 'quantity': 400},
          ],
          'settlementSource': 'Grid_20240625000000000653_1',
        },
        'summaryOnly': true,
        'quotesPending': true,
        'nextPage': 1,
        'trendPending': true,
        'monthlyTrendPending': true,
        'total': null,
        'truncated': false,
        'source': '농식품 공공데이터 포털 경매정보',
        'fetchedAt': '2026-11-20T00:05:00Z',
        'cached': false,
        'priceBasis': 'per-package',
      };
    }
    if (holdQuotes != null) {
      await holdQuotes!.future;
    }
    final page = (p['page'] as int?) ?? 1;
    final chunk = (p['chunkSize'] as int?) ?? 100;
    if (chunk >= 100 || page >= 2) {
      return {
        'sample': false,
        'product': product,
        'date': date,
        'quotes': [
          {'id': '$product-q2', 'productName': marketOrderedProducts[product] ?? product, 'market': '서울가락', 'grade': '상', 'package': '5kg 상자', 'price': 19000, 'priceBasis': 'per-package', 'quantity': 8, 'weightKg': 5, 'pricePerKg': 3800, 'date': date, 'company': '동화청과', 'auctionTime': '$date 08:30:00'},
        ],
        'nextPage': null,
        'truncated': false,
        'source': '농식품 공공데이터 포털 경매정보',
        'fetchedAt': '2026-11-20T00:05:01Z',
        'priceBasis': 'per-package',
      };
    }
    return {
      'sample': false,
      'product': product,
      'date': date,
      'quotes': [
        {'id': '$product-q1', 'productName': marketOrderedProducts[product] ?? product, 'market': '서울가락', 'grade': '특', 'package': '5kg 상자', 'price': 21000, 'priceBasis': 'per-package', 'quantity': 12, 'weightKg': 5, 'pricePerKg': 4200, 'date': date, 'company': '한국청과', 'auctionTime': '$date 08:10:00'},
      ],
      'nextPage': 2,
      'truncated': true,
      'source': '농식품 공공데이터 포털 경매정보',
      'fetchedAt': '2026-11-20T00:05:00Z',
      'priceBasis': 'per-package',
    };
  }
}

Future<void> _pumpIoAndSettle(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void addAdditionalMarketCacheTests() {
  test('marketDailyCycleKey splits days at 08:00 KST', () {
    // 2026-11-20 07:45 KST == 2026-11-19 22:45 UTC -> 2026-11-19
    expect(marketDailyCycleKey(DateTime.utc(2026, 11, 19, 22, 45)), '2026-11-19');
    // 2026-11-20 08:00 KST == 2026-11-19 23:00 UTC -> 2026-11-20
    expect(marketDailyCycleKey(DateTime.utc(2026, 11, 19, 23, 0)), '2026-11-20');
    // 2026-11-21 06:30 KST == 2026-11-20 21:30 UTC -> stays 2026-11-20
    expect(marketDailyCycleKey(DateTime.utc(2026, 11, 20, 21, 30)), '2026-11-20');
  });

  testWidgets('summary average renders first with charts in parallel while individual quotes stream in chunks', (tester) async {
    phone(tester);
    final holdQuotes = Completer<void>();
    final client = _StagedMarketClient(holdQuotes: holdQuotes)..token = 'a' * 64;
    addTearDown(client.close);

    await tester.pumpWidget(MaterialApp(
      home: MarketPricesPage(
        client: client,
        now: () => DateTime.utc(2026, 11, 20, 0, 0),
        enablePrefetch: false,
      ),
    ));
    await tester.pump();
    await tester.pump();

    // Average price & charts already rendered while individual quotes are still held
    expect(find.byKey(const Key('market-avg-price-card')), findsOneWidget);
    expect(find.text('4,100원/kg'), findsOneWidget);
    expect(find.byKey(const Key('market-trend-chart')), findsOneWidget);
    expect(find.byKey(const Key('market-monthly-trend-chart')), findsOneWidget);
    expect(find.textContaining('개별 경락가 항목을 차례로 불러오는 중'), findsOneWidget);
    expect(find.textContaining('자료가 없습니다'), findsNothing);

    holdQuotes.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('market-quote-general-tomato-q1')), findsOneWidget);
    expect(find.byKey(const ValueKey('market-quote-general-tomato-q2')), findsOneWidget);
    final chunkSizes = client.requests.where((r) => r['progressive'] == true && r['summaryOnly'] != true).map((r) => r['chunkSize']).toList();
    expect(chunkSizes, [30, 30]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reuses daily disk cache within 08:00 KST cycle, prefetches other crops, and refetches on next cycle or refresh', (tester) async {
    phone(tester);
    MarketPreferences.current = MarketPreferences(visibleProducts: {'general-tomato', 'paprika'});
    late Directory tempDir;
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp('hangyeol-market-cache-');
    });
    addTearDown(() => tempDir.deleteSync(recursive: true));

    DateTime currentNow = DateTime.utc(2026, 11, 20, 0, 0); // 09:00 KST
    final client = _StagedMarketClient()..token = 'a' * 64;
    addTearDown(client.close);

    await tester.pumpWidget(MaterialApp(
      home: MarketPricesPage(
        client: client,
        email: 'user@hangyeol.kr',
        cacheDirectory: tempDir,
        now: () => currentNow,
        enablePrefetch: true,
      ),
    ));
    await _pumpIoAndSettle(tester);

    expect(find.text('4,100원/kg'), findsOneWidget);
    // Prefetch already cached paprika too -> switching to paprika makes 0 new network calls!
    final callsAfterMount = client.requests.length;
    expect(client.requests.any((r) => r['product'] == 'paprika'), isTrue);

    await tester.tap(find.byKey(const Key('market-product-paprika')));
    await _pumpIoAndSettle(tester);
    expect(find.text('5,200원/kg'), findsOneWidget);
    expect(client.requests.length, callsAfterMount);

    // Reopen page at 20:00 KST same day -> 0 network calls, shows 저장본 표시 (매일 08시 갱신)
    currentNow = DateTime.utc(2026, 11, 20, 11, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(
      home: MarketPricesPage(
        client: client,
        email: 'user@hangyeol.kr',
        cacheDirectory: tempDir,
        now: () => currentNow,
        enablePrefetch: true,
      ),
    ));
    await _pumpIoAndSettle(tester);

    expect(client.requests.length, callsAfterMount);
    expect(find.textContaining('저장본 표시 (매일 08시 갱신)'), findsOneWidget);
    expect(find.text('4,100원/kg'), findsOneWidget);

    // Manual refresh triggers fresh requests with refresh: true
    await tester.tap(find.byKey(const Key('market-refresh')));
    await _pumpIoAndSettle(tester);
    expect(client.requests.length, greaterThan(callsAfterMount));
    expect(client.requests.any((r) => r['refresh'] == true && r['summaryOnly'] == true), isTrue);

    // Next day at 09:00 KST (Nov 21 00:00 UTC) -> daily cycle changed -> refetches automatically
    final callsBeforeNextDay = client.requests.length;
    currentNow = DateTime.utc(2026, 11, 21, 0, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(
      home: MarketPricesPage(
        client: client,
        email: 'user@hangyeol.kr',
        cacheDirectory: tempDir,
        now: () => currentNow,
        enablePrefetch: true,
      ),
    ));
    await _pumpIoAndSettle(tester);

    expect(client.requests.length, greaterThan(callsBeforeNextDay));
    expect(tester.takeException(), isNull);
  });
}
