import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/demo/demo_erp.dart';
import 'package:hangyeol_platform/src/demo/erp_report_view.dart';

void main() {
  final columns = List.generate(18, (i) => '열 제목 $i')..[17] = '마지막 제목';
  final rows = List.generate(60, (row) => List.generate(18, (column) => '거래 내역 $row-$column'));
  rows[2][1] = 'Alpha 첫 품종';
  rows[50][16] = 'ALPHA 마지막 품종';
  final report = DemoReport(columns, rows);

  Future<void> showReport(WidgetTester tester, {double width = 520, double height = 800,
    ValueChanged<List<String>>? onRowTap}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ErpReportView(
      report: report, condition: '출고 · 전체 조회 조건', online: true,
      onBack: () {}, onRowTap: onRowTap ?? (_) {},
    ))));
    await tester.pumpAndSettle();
  }

  ScrollController scroll(WidgetTester tester, String axis) =>
    tester.widget<SingleChildScrollView>(find.byKey(Key('erp-$axis-scroll'))).controller!;

  void expectMatchVisible(WidgetTester tester) {
    final viewport = tester.getRect(find.byKey(const Key('erp-table-viewport')));
    final match = tester.getRect(find.byKey(const Key('erp-active-find-cell')));
    expect(match.left, greaterThanOrEqualTo(viewport.left - .5));
    expect(match.right, lessThanOrEqualTo(viewport.right + .5));
    expect(match.top, greaterThanOrEqualTo(viewport.top - .5));
    expect(match.bottom, lessThanOrEqualTo(viewport.bottom + .5));
  }

  testWidgets('fit is an icon directly after A+ and find occupies the result summary', (tester) async {
    await showReport(tester, width: 320);
    expect(find.text('전체 열 보기'), findsNothing);
    expect(tester.widget(find.byKey(const Key('erp-fit-columns'))), isA<IconButton>());
    final fit = tester.getRect(find.byKey(const Key('erp-fit-columns')));
    final plus = tester.getRect(find.widgetWithIcon(IconButton, Icons.text_increase));
    expect(fit.center.dy, closeTo(plus.center.dy, .1));
    expect(fit.left, greaterThanOrEqualTo(plus.right - .1));
    expect(find.descendant(of: find.byKey(const Key('erp-open-find')),
      matching: find.text('찾기')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Windows mouse drag and both arrow keys move the report horizontally', (tester) async {
    var openedRows = 0;
    await showReport(tester, onRowTap: (_) => openedRows++);
    expect(tester.widget<Scrollbar>(find.byKey(const Key('erp-horizontal-scrollbar'))).thumbVisibility, isTrue);
    final horizontal = scroll(tester, 'horizontal');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(horizontal.offset, greaterThan(0));
    final right = horizontal.offset;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(horizontal.offset, lessThan(right));
    final firstX = tester.getRect(find.text('열 제목 0')).left;
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('erp-table-viewport'))),
      kind: PointerDeviceKind.mouse);
    // First cross the drag threshold, then send movement after recognition.
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(horizontal.offset, greaterThan(0));
    expect(tester.getRect(find.text('열 제목 0')).left, lessThan(firstX));
    expect(openedRows, 0, reason: 'Dragging must not open the row detail.');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant(<TargetPlatform>{TargetPlatform.windows}));

  testWidgets('Ctrl+F finds cells on both axes, wraps matches and works after scaling', (tester) async {
    await showReport(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    final input = find.byKey(const Key('erp-find-input'));
    expect(input, findsOneWidget);
    await tester.enterText(input, 'alpha');
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
    expectMatchVisible(tester);

    await tester.tap(find.byKey(const Key('erp-find-next')));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('erp-active-find-cell'))).data, 'ALPHA 마지막 품종');
    expect(scroll(tester, 'horizontal').offset, greaterThan(0));
    expect(scroll(tester, 'vertical').offset, greaterThan(0));
    expectMatchVisible(tester);

    await tester.tap(input);
    await tester.pumpAndSettle();
    final beforeTypingArrow = scroll(tester, 'horizontal').offset;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(scroll(tester, 'horizontal').offset, closeTo(beforeTypingArrow, .1));

    await tester.tap(find.byKey(const Key('erp-find-next')));
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
    expectMatchVisible(tester);
    await tester.tap(find.byKey(const Key('erp-find-previous')));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
    expectMatchVisible(tester);

    await tester.tap(find.byKey(const Key('erp-fit-columns')));
    await tester.pumpAndSettle();
    expectMatchVisible(tester);
    await tester.enterText(input, '마지막 제목');
    await tester.pumpAndSettle();
    expect(find.text('1/1'), findsOneWidget);
    expectMatchVisible(tester);
    await tester.enterText(input, '해당 내용 없음');
    await tester.pumpAndSettle();
    expect(find.text('0/0'), findsOneWidget);
    expect(find.text('일치하는 내용이 없습니다.'), findsOneWidget);
    expect(find.byKey(const Key('erp-active-find-cell')), findsNothing);
    await tester.tap(find.byTooltip('찾기 닫기'));
    await tester.pumpAndSettle();
    expect(input, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant(<TargetPlatform>{TargetPlatform.windows}));

  testWidgets('mobile search remains usable with a keyboard on a narrow screen', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await showReport(tester, width: 320, height: 700);
    await tester.tap(find.byKey(const Key('erp-open-find')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('erp-find-input')), 'alpha');
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
    expectMatchVisible(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant(<TargetPlatform>{TargetPlatform.android}));
}
