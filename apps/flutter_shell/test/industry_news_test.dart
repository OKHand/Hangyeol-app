import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';
import 'package:hangyeol_platform/src/serverless/industry_news.dart';
import 'package:hangyeol_platform/src/serverless/news_discord_settings.dart';

class _NewsClient extends AppsScriptPlatformClient {
  _NewsClient() : super(Uri.parse('https://script.google.com/macros/s/news-test/exec'));
  final calls = <String>[];
  final callParams = <Map<String, dynamic>?>[];
  Map<String, dynamic>? lastConfigure;
  bool webhookConfigured = false;
  bool weeklyEnabled = false;
  final articles = <Map<String, dynamic>>[
    {
      'id': 'a1',
      'publishedAt': '2026-11-17T01:40:00Z',
      'track': '병해충·작황',
      'crops': ['토마토', '고추'],
      'importance': 4,
      'title': '토마토갈색주름과실바이러스 확산 주의',
      'facts': '• 토마토·고추류 피해 확산 우려',
      'aiNote': '',
      'source': '농수축산신문',
      'url': 'https://example.com/1',
      'relatedCount': 1,
      'relatedUrls': [
        {'source': '한국농정신문', 'title': '관련 보도', 'url': 'https://example.com/r1'}
      ],
    },
    {
      'id': 'a2',
      'publishedAt': '2026-11-16T08:00:00Z',
      'track': '작물·품종',
      'crops': ['파프리카'],
      'importance': 3,
      'title': '파프리카 신품종 육성 동향',
      'facts': '',
      'aiNote': '',
      'source': '한국농어민신문',
      'url': 'https://example.com/2',
      'relatedCount': 0,
      'relatedUrls': <Map<String, dynamic>>[],
    },
  ];

  @override
  Future<Map<String, dynamic>> call(String action, {Map<String, dynamic>? params, bool authenticated = true}) async {
    calls.add(action);
    callParams.add(params == null ? null : Map<String, dynamic>.from(params));
    if (action == 'news.list') {
      return {
        'articles': articles,
        'sources': [
          {'name': '농수축산신문', 'enabled': true, 'lastError': ''}
        ],
        'fetchedAt': '2026-11-17T01:45:00Z',
        'cached': false,
      };
    }
    if (action == 'news.feedback') {
      articles.removeWhere((a) => a['id'] == params?['id']);
      return {'recorded': true, 'id': params?['id']};
    }
    if (action == 'news.settings') {
      return {
        'webhookConfigured': webhookConfigured,
        'weeklyEnabled': weeklyEnabled,
        'scheduleLabel': '매주 월요일 오전 10시 (KST)',
        'lastSentAt': '',
        'lastSentCount': 0,
        'settingsVersion': 'v1',
        'sheetUrl': 'https://docs.google.com/spreadsheets/d/test/edit',
      };
    }
    if (action == 'news.configure') {
      lastConfigure = Map<String, dynamic>.from(params ?? {});
      if (params != null && params.containsKey('webhook')) {
        webhookConfigured = (params['webhook'] as String).isNotEmpty;
      }
      if (params?['weeklyEnabled'] is bool) {
        weeklyEnabled = params!['weeklyEnabled'] == true;
      }
      return {
        'webhookConfigured': webhookConfigured,
        'weeklyEnabled': weeklyEnabled,
        'scheduleLabel': '매주 월요일 오전 10시 (KST)',
        'lastSentAt': '',
        'lastSentCount': 0,
        'settingsVersion': 'v2',
        'sheetUrl': 'https://docs.google.com/spreadsheets/d/test/edit',
      };
    }
    if (action == 'news.sendWeekly') {
      return {'sent': true, 'count': 2};
    }
    throw StateError('Unexpected action: $action');
  }
}

void main() {
  testWidgets('IndustryNewsPage loads articles, filters tracks, expands related links and sends irrelevant feedback', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final client = _NewsClient()..token = 'a' * 64;
    addTearDown(client.close);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: IndustryNewsPage(client: client, onAuthError: (_) async {}))));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('news-card-a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('news-card-a2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('news-track-작물·품종')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('news-card-a1')), findsNothing);
    expect(find.byKey(const ValueKey('news-card-a2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('news-track-전체')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('유사보도 1건'));
    await tester.pumpAndSettle();
    expect(find.textContaining('관련 보도'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('news-irrelevant-a2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('news-card-a2')), findsNothing);
    expect(client.calls, contains('news.feedback'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('NewsDiscordSettingsPage saves webhook URL and weekly Monday 10am schedule', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final client = _NewsClient()..token = 'a' * 64;
    addTearDown(client.close);

    await tester.pumpWidget(MaterialApp(home: NewsDiscordSettingsPage(client: client, onAuthError: (_) async {})));
    await tester.pumpAndSettle();

    expect(find.text('미연결'), findsOneWidget);
    await tester.tap(find.byKey(const Key('news-change-webhook')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('news-discord-webhook-input')),
      'https://discord.com/api/webhooks/123456789012345/abcdefabcdefabcdefabcdefabcdef',
    );
    await tester.tap(find.byKey(const Key('news-weekly-switch')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('news-discord-save')));
    await tester.pumpAndSettle();

    expect(client.lastConfigure, {
      'expectedVersion': 'v1',
      'webhook': 'https://discord.com/api/webhooks/123456789012345/abcdefabcdefabcdefabcdefabcdef',
      'weeklyEnabled': true,
    });
    expect(find.text('연결됨'), findsOneWidget);

    expect(find.byKey(const Key('news-discord-test-send')), findsOneWidget);
    expect(find.textContaining('최대 10건'), findsOneWidget);

    await tester.tap(find.byKey(const Key('news-discord-test-send')));
    await tester.pumpAndSettle();
    expect(client.calls, contains('news.sendWeekly'));
    expect(tester.takeException(), isNull);
  });

  test('newsDailyCycleKey splits days at 07:30 KST', () {
    // 2026-11-20 07:15 KST == 2026-11-19 22:15 UTC -> still 2026-11-19 cycle
    expect(newsDailyCycleKey(DateTime.utc(2026, 11, 19, 22, 15)), '2026-11-19');
    // 2026-11-20 07:30 KST == 2026-11-19 22:30 UTC -> switches to 2026-11-20 cycle
    expect(newsDailyCycleKey(DateTime.utc(2026, 11, 19, 22, 30)), '2026-11-20');
    // 2026-11-21 06:00 KST == 2026-11-20 21:00 UTC -> stays in 2026-11-20 cycle
    expect(newsDailyCycleKey(DateTime.utc(2026, 11, 20, 21, 0)), '2026-11-20');
  });

  Future<void> pumpIoAndSettle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('IndustryNewsPage reuses disk cache within same daily cycle, persists dismissal, and refetches after 07:30 KST or manual refresh', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    late Directory tempDir;
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp('hangyeol-news-cache-');
    });
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final cacheFile = File('${tempDir.path}${Platform.pathSeparator}news_cache.json');

    // Day 1 at 09:00 KST (00:00 UTC) -> fetches once from server and writes disk cache
    DateTime currentNow = DateTime.utc(2026, 11, 20, 0, 0);
    final client = _NewsClient()..token = 'a' * 64;
    addTearDown(client.close);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IndustryNewsPage(
          client: client,
          onAuthError: (_) async {},
          email: 'user@hangyeol.kr',
          cacheFile: cacheFile,
          now: () => currentNow,
        ),
      ),
    ));
    await pumpIoAndSettle(tester);

    expect(client.calls.where((c) => c == 'news.list').length, 1);
    expect(find.byKey(const ValueKey('news-card-a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('news-card-a2')), findsOneWidget);

    // Dismiss a2 -> updates both server feedback & local disk cache
    await tester.tap(find.byKey(const ValueKey('news-irrelevant-a2')));
    await pumpIoAndSettle(tester);
    expect(find.byKey(const ValueKey('news-card-a2')), findsNothing);

    // Reopen page same day at 21:00 KST (12:00 UTC) -> 0 new news.list calls, a2 remains absent, shows 저장본 표시
    currentNow = DateTime.utc(2026, 11, 20, 12, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IndustryNewsPage(
          client: client,
          onAuthError: (_) async {},
          email: 'user@hangyeol.kr',
          cacheFile: cacheFile,
          now: () => currentNow,
        ),
      ),
    ));
    await pumpIoAndSettle(tester);

    expect(client.calls.where((c) => c == 'news.list').length, 1);
    expect(find.textContaining('저장본 표시'), findsOneWidget);
    expect(find.byKey(const ValueKey('news-card-a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('news-card-a2')), findsNothing);

    // Manual refresh triggers news.list with refresh: true
    await tester.tap(find.byKey(const Key('news-refresh')));
    await pumpIoAndSettle(tester);
    expect(client.calls.where((c) => c == 'news.list').length, 2);
    expect(client.callParams.last?['refresh'], true);

    // Next day at 08:00 KST (Nov 20 23:00 UTC) -> daily cycle changed, auto-refetches cleanly
    currentNow = DateTime.utc(2026, 11, 20, 23, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IndustryNewsPage(
          client: client,
          onAuthError: (_) async {},
          email: 'user@hangyeol.kr',
          cacheFile: cacheFile,
          now: () => currentNow,
        ),
      ),
    ));
    await pumpIoAndSettle(tester);

    expect(client.calls.where((c) => c == 'news.list').length, 3);
    expect(tester.takeException(), isNull);
  });
}
