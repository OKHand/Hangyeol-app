import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'demo_erp.dart';
import '../ui/hangyeol_theme.dart';

/// Scales the whole report, including cell spacing and row heights.
class ErpReportView extends StatefulWidget {
  const ErpReportView({super.key, required this.report, required this.condition,
    required this.online, required this.onBack, required this.onRowTap});
  final DemoReport report;
  final String condition;
  final bool online;
  final VoidCallback onBack;
  final ValueChanged<List<String>> onRowTap;

  @override
  State<ErpReportView> createState() => _ErpReportViewState();
}

class _ErpReportViewState extends State<ErpReportView> {
  final _tableKey = GlobalKey();
  final _activeCellKey = GlobalKey();
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  final _reportFocus = FocusNode();
  final _findFocus = FocusNode();
  final _findText = TextEditingController();
  Size? _naturalSize;
  double _zoom = 1;
  bool _fitWidth = false, _findOpen = false;
  List<({int row, int column})> _matches = [];
  Set<({int row, int column})> _matchingCells = {};
  int _matchIndex = -1, _revealVersion = 0;

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    _reportFocus.dispose();
    _findFocus.dispose();
    _findText.dispose();
    super.dispose();
  }

  void _measureTable() {
    if (!mounted) { return; }
    final box = _tableKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize && box.size != _naturalSize) {
      setState(() => _naturalSize = box.size);
    }
  }

  void _revealMatch() {
    final version = ++_revealVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || version != _revealVersion || !_findOpen || _matchIndex < 0) { return; }
      final cell = _activeCellKey.currentContext;
      if (cell != null) {
        // ensureVisible follows both scroll axes and the table's scale transform.
        Scrollable.ensureVisible(cell, alignment: .5,
          duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
      }
    });
  }

  void _search(String value) {
    final query = value.trim().toLowerCase();
    final found = <({int row, int column})>[];
    if (query.isNotEmpty) {
      for (final column in widget.report.columns.indexed) {
        if (column.$2.toLowerCase().contains(query)) { found.add((row: -1, column: column.$1)); }
      }
      for (final row in widget.report.rows.indexed) {
        for (final cell in row.$2.indexed) {
          if (cell.$2.toLowerCase().contains(query)) { found.add((row: row.$1, column: cell.$1)); }
        }
      }
    }
    setState(() { _matches = found; _matchingCells = found.toSet(); _matchIndex = found.isEmpty ? -1 : 0; });
    _revealMatch();
  }

  void _openFind() {
    if (widget.report.rows.isEmpty) { return; }
    setState(() => _findOpen = true);
    _search(_findText.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_findOpen) { return; }
      _findFocus.requestFocus();
      _findText.selection = TextSelection(baseOffset: 0, extentOffset: _findText.text.length);
    });
  }

  void _closeFind() {
    setState(() { _findOpen = false; _matches = []; _matchingCells = {}; _matchIndex = -1; });
    _revealVersion++;
    _reportFocus.requestFocus();
  }

  void _moveMatch(int delta) {
    if (_matches.isEmpty) { return; }
    setState(() => _matchIndex = (_matchIndex + delta) % _matches.length);
    _revealMatch();
  }

  void _changeZoom(double current, double factor) {
    setState(() { _zoom = (current * factor).clamp(.01, 3).toDouble(); _fitWidth = false; });
    _revealMatch();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (_findFocus.hasFocus || event is! KeyDownEvent && event is! KeyRepeatEvent || !_horizontal.hasClients) {
      return KeyEventResult.ignored;
    }
    final direction = event.logicalKey == LogicalKeyboardKey.arrowRight ? 1
      : event.logicalKey == LogicalKeyboardKey.arrowLeft ? -1 : 0;
    if (direction == 0) { return KeyEventResult.ignored; }
    final position = _horizontal.position;
    _horizontal.jumpTo((position.pixels + direction * 120).clamp(0.0, position.maxScrollExtent).toDouble());
    return KeyEventResult.handled;
  }

  bool _active(int row, int column) => _matchIndex >= 0 &&
    _matches[_matchIndex] == (row: row, column: column);

  Widget _cell(String value, int row, int column, {bool heading = false}) {
    final active = _active(row, column);
    Widget text = Text(value, key: active ? const Key('erp-active-find-cell') : null,
      style: TextStyle(fontSize: 12, fontWeight: heading ? FontWeight.bold : null,
        color: !heading && value.startsWith('-') ? const Color(0xff965044) : null));
    if (!heading) {
      text = Align(alignment: num.tryParse(value.replaceAll(',', '')) == null
        ? Alignment.centerLeft : Alignment.centerRight, child: text);
    }
    if (!_matchingCells.contains((row: row, column: column))) { return text; }
    return DecoratedBox(key: active ? _activeCellKey : null,
      decoration: BoxDecoration(color: active ? const Color(0xffffd36a) : const Color(0xfffff0b3),
        border: active ? Border.all(color: const Color(0xff865c00), width: 2) : null), child: text);
  }

  Widget _table() => DataTable(
    key: _tableKey,
    headingRowHeight: 36, dataRowMinHeight: 34, dataRowMaxHeight: 48,
    horizontalMargin: 10, columnSpacing: 16,
    headingRowColor: const WidgetStatePropertyAll(Color(0xffe7efe9)),
    columns: widget.report.columns.indexed.map((column) =>
      DataColumn(label: _cell(column.$2, -1, column.$1, heading: true))).toList(),
    rows: widget.report.rows.indexed.map((row) => DataRow(
      color: WidgetStatePropertyAll(row.$2.first == '[ 총 합 계 ]'
        ? const Color(0xffdce9df)
        : row.$1.isEven ? Colors.white : const Color(0xfff4f7f4)),
      cells: row.$2.indexed.map((cell) => DataCell(_cell(cell.$2, row.$1, cell.$1),
        onTap: () => widget.onRowTap(row.$2))).toList(),
    )).toList(),
  );

  Widget _findBar() => TextFieldTapRegion(child: Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: Column(children: [
      Row(children: [
        Expanded(child: TextField(key: const Key('erp-find-input'), controller: _findText,
          focusNode: _findFocus, onChanged: _search, onSubmitted: (_) => _moveMatch(1),
          onTapOutside: (_) => _findFocus.unfocus(),
          decoration: const InputDecoration(labelText: '찾을 글자', isDense: true, border: OutlineInputBorder()))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(
          '${_matchIndex < 0 ? 0 : _matchIndex + 1}/${_matches.length}',
          key: const Key('erp-find-count'), style: const TextStyle(fontSize: 12))),
        IconButton(key: const Key('erp-find-previous'), tooltip: '이전 일치 항목',
          onPressed: _matches.isEmpty ? null : () => _moveMatch(-1), icon: const Icon(Icons.keyboard_arrow_up)),
        IconButton(key: const Key('erp-find-next'), tooltip: '다음 일치 항목',
          onPressed: _matches.isEmpty ? null : () => _moveMatch(1), icon: const Icon(Icons.keyboard_arrow_down)),
        IconButton(tooltip: '찾기 닫기', onPressed: _closeFind, icon: const Icon(Icons.close)),
      ]),
      if (_findText.text.trim().isNotEmpty && _matches.isEmpty)
        const Align(alignment: Alignment.centerLeft, child: Text('일치하는 내용이 없습니다.', style: TextStyle(fontSize: 12))),
    ]),
  ));

  Widget _scrollingTable(Widget table) {
    final platform = Theme.of(context).platform;
    final desktop = [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux].contains(platform);
    final behavior = ScrollConfiguration.of(context);
    return ScrollConfiguration(behavior: behavior.copyWith(scrollbars: false,
      dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse}),
      child: Listener(onPointerDown: (_) => _reportFocus.requestFocus(),
        child: SizedBox.expand(key: const Key('erp-table-viewport'), child: Scrollbar(
          key: const Key('erp-horizontal-scrollbar'),
          controller: _horizontal, thumbVisibility: desktop, interactive: true,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          notificationPredicate: (event) => event.metrics.axis == Axis.horizontal,
          child: Scrollbar(key: const Key('erp-vertical-scrollbar'),
            controller: _vertical, thumbVisibility: desktop, interactive: true,
            scrollbarOrientation: ScrollbarOrientation.right,
            notificationPredicate: (event) => event.metrics.axis == Axis.vertical,
            child: SingleChildScrollView(key: const Key('erp-vertical-scroll'), controller: _vertical,
              child: SingleChildScrollView(key: const Key('erp-horizontal-scroll'), controller: _horizontal,
                scrollDirection: Axis.horizontal, child: table)),
          ),
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, viewport) {
    if (widget.report.rows.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureTable());
    }
    final natural = _naturalSize;
    final scale = _fitWidth && natural != null && natural.width > 0
      ? math.min(1.0, viewport.maxWidth / natural.width) : _zoom;
    final table = _table();
    final header = Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: SizedBox(width: double.infinity, child: Wrap(
          alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back), label: const Text('조회 조건')),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: '표 복사', onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.report.csv()));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('열 제목과 전체 결과를 CSV로 복사했습니다.')));
                }
              }, icon: const Icon(Icons.copy_outlined)),
              IconButton(tooltip: '글자 작게', onPressed: scale <= .01 ? null
                : () => _changeZoom(scale, 1 / 1.2), icon: const Icon(Icons.text_decrease)),
              Tooltip(message: '표 크기 초기화', child: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(42, 40), padding: EdgeInsets.zero),
                onPressed: () { setState(() { _zoom = 1; _fitWidth = false; }); _revealMatch(); },
                child: Text('${(scale * 100).round()}%', style: const TextStyle(fontSize: 12)),
              )),
              IconButton(tooltip: '글자 크게', onPressed: scale >= 3 ? null
                : () => _changeZoom(scale, 1.2), icon: const Icon(Icons.text_increase)),
              IconButton(key: const Key('erp-fit-columns'), tooltip: '전체 열 보기',
                onPressed: widget.report.rows.isEmpty ? null : () {
                  setState(() => _fitWidth = true); _revealMatch();
                }, icon: const Icon(Icons.fit_screen)),
            ]),
          ],
        ))),
      Container(width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: kHangyeolSurface, borderRadius: BorderRadius.circular(12)),
        child: Text(widget.condition, style: const TextStyle(fontSize: 12, color: kHangyeolInk))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
        Expanded(child: Text('결과 ${widget.report.rows.where((r) => r.first != '[ 총 합 계 ]').length}건${widget.online ? "" : " · 샘플 자료"}',
          style: const TextStyle(fontSize: 12, color: kHangyeolMuted))),
        TextButton.icon(key: const Key('erp-open-find'), onPressed: widget.report.rows.isEmpty ? null : _openFind,
          icon: const Icon(Icons.search, size: 18), label: const Text('찾기')),
      ])),
      if (_findOpen) _findBar() else const Divider(height: 1, color: kHangyeolDivider),
    ]);
    return CallbackShortcuts(bindings: {
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): _openFind,
      const SingleActivator(LogicalKeyboardKey.f3): () { if (_findOpen) { _moveMatch(1); } else { _openFind(); } },
      const SingleActivator(LogicalKeyboardKey.f3, shift: true): () => _moveMatch(-1),
      if (_findOpen) const SingleActivator(LogicalKeyboardKey.escape): _closeFind,
    }, child: Focus(focusNode: _reportFocus, autofocus: true, onKeyEvent: _handleKey,
      child: Column(children: [
        ConstrainedBox(constraints: BoxConstraints(maxHeight: viewport.maxHeight * .65),
          child: SingleChildScrollView(primary: false, child: header)),
        Expanded(child: widget.report.rows.isEmpty
          ? const Center(child: Text('조건에 맞는 내역이 없습니다.\n조회 조건으로 돌아가 조건을 바꿔 주세요.', textAlign: TextAlign.center))
          : _scrollingTable(natural == null ? table : SizedBox(
              key: const Key('erp-scaled-table'), width: natural.width * scale, height: natural.height * scale,
              child: FittedBox(fit: BoxFit.fill, alignment: Alignment.topLeft, child: table),
            )),
        ),
      ]),
    ));
  });
}
