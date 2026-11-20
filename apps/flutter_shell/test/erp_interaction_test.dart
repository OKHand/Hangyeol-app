import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/demo/demo_erp.dart';
import 'package:hangyeol_platform/src/demo/demo_erp_page.dart';
import 'package:hangyeol_platform/src/demo/erp_report_view.dart';

void main() {
  final report = DemoReport(
    List.generate(18, (i) => '열 제목 $i'),
    List.generate(12, (row) => List.generate(18, (column) => '거래 내역 $row-$column')),
  );

  for (final width in [320.0, 1280.0]) {
    testWidgets('report scales complete rows and columns and fits all columns at $width px', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      List<String>? selected;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ErpReportView(
        report: report, condition: '출고 · 회사 원장', online: true, onBack: () {},
        onRowTap: (row) => selected = row,
      ))));
      await tester.pumpAndSettle();
      final scaled = find.byKey(const Key('erp-scaled-table'));
      final original = tester.getSize(scaled);
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byTooltip('글자 작게'));
        await tester.pumpAndSettle();
      }
      final smaller = tester.getSize(scaled);
      expect(smaller.width, lessThan(original.width * .5));
      expect(smaller.height / original.height, closeTo(smaller.width / original.width, .001));
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.text_decrease)).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('erp-fit-columns')));
      await tester.pumpAndSettle();
      expect(tester.getSize(scaled).width, closeTo(width, .1));
      expect(find.text('열 제목 17'), findsOneWidget);
      // The rightmost column is actually visible, not merely present off-screen.
      final lastColumn = tester.getRect(find.text('열 제목 17'));
      expect(lastColumn.left, greaterThanOrEqualTo(0));
      expect(lastColumn.right, lessThanOrEqualTo(width + .1));
      await tester.tap(find.text('거래 내역 0-17'));
      await tester.pumpAndSettle();
      expect(selected, report.rows.first);

      tester.view.physicalSize = Size(width + 100, 900);
      await tester.pumpAndSettle();
      expect(tester.getSize(scaled).width, closeTo(width + 100, .1));
      await tester.tap(find.byTooltip('표 크기 초기화'));
      await tester.pumpAndSettle();
      expect(tester.getSize(scaled).width, closeTo(original.width, .1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('mobile outside touch dismisses suggestions and a single tap still activates the button', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var queries = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Padding(
      padding: const EdgeInsets.all(20), child: Column(children: [
        DemoMultiField(controller: controller, options: const ['나상 가명A종묘'],
          label: '거래처명', hint: '일부 검색', fieldKey: 'customer'),
        const SizedBox(height: 100),
        const Text('입력칸 밖 안내', key: Key('outside-field')),
        const Spacer(),
        FilledButton(key: const Key('query-button'), onPressed: () => queries++, child: const Text('조회 확인')),
      ]),
    ))));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('demo-customer'));
    await tester.enterText(field, '가명A');
    await tester.pumpAndSettle();
    expect(find.text('나상 가명A종묘'), findsOneWidget);
    await tester.tap(find.byKey(const Key('outside-field')), kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    expect(find.text('나상 가명A종묘'), findsNothing);
    expect(controller.text, '가명A');

    await tester.tap(field, kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    expect(find.text('나상 가명A종묘'), findsOneWidget);
    await tester.tap(find.text('나상 가명A종묘'), kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    expect(controller.text, '나상 가명A종묘, ');

    await tester.enterText(field, '가명A');
    await tester.pumpAndSettle();
    expect(find.text('나상 가명A종묘'), findsOneWidget);
    await tester.tap(find.byKey(const Key('query-button')), kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    expect(queries, 1);
    expect(find.text('나상 가명A종묘'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant(<TargetPlatform>{TargetPlatform.android}));

  testWidgets('all six ERP mode chips fit on a single horizontal row on standard 360px Android screen', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: DemoErpPage())));
    await tester.pumpAndSettle();

    final firstTop = tester.getRect(find.widgetWithText(ChoiceChip, '입고')).top;
    for (final mode in ['출고', '통합', '요약', '집계', '재고']) {
      final top = tester.getRect(find.widgetWithText(ChoiceChip, mode)).top;
      expect(top, closeTo(firstTop, 0.5), reason: 'Expected $mode chip to remain on the first row at 360px width');
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
