import 'package:flutter/material.dart';
import 'demo_erp.dart';
import 'erp_report_view.dart';

const demoGreen = Color(0xff1e6247);
class DemoErpPage extends StatefulWidget {
  const DemoErpPage({super.key,this.loadReport,this.loadSuggestions,this.refreshSuggestions});
  final Future<DemoReport> Function(DemoQuery)? loadReport;
  final Future<Map<String,List<String>>> Function()? loadSuggestions;
  final Future<Map<String,List<String>>> Function()? refreshSuggestions;
  bool get online => loadReport != null;
  @override
  State<DemoErpPage> createState() => _DemoErpPageState();
}
class _DemoErpPageState extends State<DemoErpPage> {
  final _fields = {for (final key in ['customer','div','item','sales','origin']) key: TextEditingController()};
  String _mode = '출고', _view = 'A', _stock = '규격별', _group = 'detail';
  DateTime? _start, _end;
  DemoReport? _result;
  String _condition = '', _error = '';
  bool _busy = false, _suggestionsBusy = false;
  Map<String,List<String>> _options = {};
  @override
  void initState() { super.initState(); if (widget.online) { _refreshSuggestions(); } }
  List<String> _suggestions(String field) => widget.online ? (_options[field] ?? []) : _query.suggestions(field);
  Future<void> _refreshSuggestions({bool force=false}) async {
    if (widget.loadSuggestions == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('기기에 포함된 최신 샘플 추천어입니다.'))); return; }
    setState(()=>_suggestionsBusy=true);
    try { final loader=force?(widget.refreshSuggestions??widget.loadSuggestions):widget.loadSuggestions; final values=await loader!(); if(mounted){setState(()=>_options=values);} }
    catch(error){if(mounted){setState(()=>_error=error.toString());}}
    finally{if(mounted){setState(()=>_suggestionsBusy=false);}}
  }
  @override
  void dispose() { for (final c in _fields.values) { c.dispose(); } super.dispose(); }
  DemoQuery get _query => DemoQuery(mode: _mode, customer: _fields['customer']!.text, div: _fields['div']!.text, item: _fields['item']!.text, sales: _fields['sales']!.text, origin: _fields['origin']!.text, start: _start, end: _end, view: _mode == '재고' ? _stock : _view, groupBy: _group);
  Future<void> _run() async {
    if(_busy){return;}
    final query=_query;
    final requestedMode=_mode;
    final snapshotCondition=_mode == '재고' ? '재고 · $_stock' : '$_mode | ${_fields.entries.where((e)=>e.value.text.trim().isNotEmpty).map((e)=>e.value.text.trim()).join(" · ")} | ${_start==null?"전체":demoDay(_start!)} ~ ${_end==null?"전체":demoDay(_end!)}';
    setState(()=>_busy=true);
    FocusScope.of(context).unfocus();
    try {
      final report = widget.loadReport == null ? query.report() : await widget.loadReport!(query);
      if(!mounted||requestedMode!=_mode){return;}
      setState(() {
        _result = report; _error = '';
        _condition = report.title ?? snapshotCondition;
      });
    } catch (error) { if(mounted){setState(() => _error = error.toString().replaceFirst('Invalid argument(s): ', ''));} }
    finally { if(mounted){setState(()=>_busy=false);} }
  }
  void _reset() { setState(() { for (final c in _fields.values) { c.clear(); } _start = null; _end = null; _view = 'A'; _stock = '규격별'; _group = 'detail'; _error = ''; }); }
  Future<void> _date(bool start) async {
    final date = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2040), initialDate: (start ? _start : _end) ?? DateTime(2026,11,start ? 1 : 10), helpText: start ? '시작일' : '종료일');
    if (date != null && mounted) { setState(() { if (start) { _start = date; } else { _end = date; } }); }
  }
  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) { return _results(result); }
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 12), children: [
      const Text('ERP 조회', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      if (!widget.online) ...[const SizedBox(height: 2), const Text('가상 원장 21건 · 체험 기준일 2026-11-10', style: TextStyle(fontSize: 12, color: Color(0xff52685c)))],
      const SizedBox(height: 6),
      Wrap(spacing: 4, runSpacing: 2, children: demoModes.map((mode) => ChoiceChip(showCheckmark: false, labelPadding: const EdgeInsets.symmetric(horizontal: 3), visualDensity: VisualDensity.compact, label: Text(mode, style: const TextStyle(fontSize: 13)), selected: _mode == mode, onSelected: _busy ? null : (_) => setState(() { _mode = mode; _error = ''; }))).toList()), const SizedBox(height: 8),
      Card(margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_mode != '재고') ...[
          Row(children: [const Expanded(child: Text('거래처명', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))), TextButton.icon(style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)), onPressed: _suggestionsBusy ? null : () => _refreshSuggestions(force:true), icon: const Icon(Icons.refresh, size: 15), label: const Text('추천어 갱신', style: TextStyle(fontSize: 12)))]),
          DemoMultiField(fieldKey: 'customer', controller: _fields['customer']!, options: _suggestions('customer'), hint: '예: 가명A종묘, 가명C종묘', label: '거래처명'),
          const SizedBox(height: 8), const Text('날짜 범위', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 4),
          Row(children: [Expanded(child: OutlinedButton(onPressed: () => _date(true), child: Text(_start == null ? '시작일 전체' : demoDay(_start!), style: const TextStyle(fontSize: 12)))), const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('~')), Expanded(child: OutlinedButton(onPressed: () => _date(false), child: Text(_end == null ? '종료일 전체' : demoDay(_end!), style: const TextStyle(fontSize: 12))))]),
          if (_start != null || _end != null) Align(alignment: Alignment.centerRight, child: TextButton(style: TextButton.styleFrom(visualDensity: VisualDensity.compact), onPressed: () => setState(() { _start = null; _end = null; }), child: const Text('기간 해제', style: TextStyle(fontSize: 12)))),
          ...[('div','구분','예: 매출, 반품'),('item','품목','예: 토마토, 고추'),('sales','판매품종명','예: 체험 루비'),('origin','원품종명','예: R-101')].map((f) => Padding(padding: const EdgeInsets.only(top: 8), child: DemoMultiField(fieldKey: f.$1, controller: _fields[f.$1]!, options: _suggestions(f.$1), label: f.$2, hint: f.$3))),
        ],
        if (_mode == '집계') ...[
          const SizedBox(height: 10), DropdownButtonFormField<String>(key: ValueKey('agg-$_view'), initialValue: _view, decoration: const InputDecoration(labelText: '조회 뷰 (표시 형식)'), isExpanded: true, items: const [DropdownMenuItem(value: 'A', child: Text('A. 선택 거래처 품목별 집계', style: TextStyle(fontSize: 13))),DropdownMenuItem(value: 'B', child: Text('B. 품목 중심 거래처별 집계', style: TextStyle(fontSize: 13))),DropdownMenuItem(value: 'C', child: Text('C. 거래처 중심 품목별 집계', style: TextStyle(fontSize: 13)))], onChanged: (v) => setState(() => _view = v!)),
        ],
        if (_mode == '재고') ...[
          DropdownButtonFormField<String>(key: ValueKey('stock-$_stock'), initialValue: _stock, decoration: const InputDecoration(labelText: '재고 조회 방식'), items: const [DropdownMenuItem(value: '규격별', child: Text('규격별 조회')),DropdownMenuItem(value: '총량', child: Text('총량 환산 조회'))], onChanged: (v) => setState(() => _stock = v!)), const SizedBox(height: 10),
          DropdownButtonFormField<String>(key: ValueKey('group-$_group'), initialValue: _group, decoration: const InputDecoration(labelText: '품종 묶음 기준'), items: const [DropdownMenuItem(value: 'detail', child: Text('판매품종 + 원품종')),DropdownMenuItem(value: 'origin', child: Text('원품종 기준 병합'))], onChanged: (v) => setState(() => _group = v!)),
        ],
        if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 10), Row(children: [OutlinedButton(key: const Key('demo-reset'), onPressed: _busy ? null : _reset, child: const Text('초기화')), const SizedBox(width: 8), Expanded(child: FilledButton.icon(key: const Key('demo-query'), onPressed: _busy ? null : _run, icon: const Icon(Icons.search), label: Text(_busy ? '조회 중…' : '조회 확인')))]),
      ]))),
      if(!widget.online)...[const SizedBox(height: 10), const Text('빠른 체험', style: TextStyle(fontWeight: FontWeight.bold)),
      Wrap(spacing: 6, children: [ActionChip(label: const Text('가명A종묘 거래'), onPressed: () { _reset(); setState(() { _mode = '출고'; _fields['customer']!.text = '가명A종묘'; }); _run(); }),ActionChip(label: const Text('입금·반품 내역'), onPressed: () { _reset(); setState(() { _mode = '출고'; _fields['div']!.text = '입금, 반품'; }); _run(); }),ActionChip(label: const Text('품목별 수량 집계'), onPressed: () { _reset(); setState(() => _mode = '집계'); _run(); })]),
      ],
    ]);
  }
  Widget _results(DemoReport report) => ErpReportView(
    key: ObjectKey(report), report: report, condition: _condition, online: widget.online,
    onBack: () => setState(() => _result = null),
    onRowTap: (row) => _detail(report, row),
  );
  void _detail(DemoReport report, List<String> row) => showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (context) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .72, child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [const Text('조회 내역 상세', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 10), ...report.columns.indexed.map((c) => ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(c.$2, style: const TextStyle(fontSize: 12, color: Color(0xff52685c))), subtitle: SelectableText(row[c.$1].isEmpty ? '—' : row[c.$1])))]))));
}
class DemoMultiField extends StatefulWidget {
  const DemoMultiField({super.key, required this.controller, required this.options, required this.label, required this.hint, required this.fieldKey});
  final TextEditingController controller;
  final List<String> options;
  final String label, hint, fieldKey;
  @override
  State<DemoMultiField> createState() => _DemoMultiFieldState();
}
class _DemoMultiFieldState extends State<DemoMultiField> {
  final _focus = FocusNode();
  String _typed = '';
  @override
  void dispose() { _focus.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => RawAutocomplete<String>(textEditingController: widget.controller, focusNode: _focus,
    optionsBuilder: (value) {
      final query = demoNormalize(value.text.split(RegExp('[,，]')).last);
      final selected = demoTokens(value.text);
      return widget.options.where((v) => !selected.contains(v) && demoNormalize(v).contains(query)).take(15);
    },
    onSelected: (name) { final previous = _typed.split(RegExp('[,，]'))..removeLast(); widget.controller.text = "${[...previous.map((s) => s.trim()).where((s) => s.isNotEmpty), name].join(', ')}, "; widget.controller.selection = TextSelection.collapsed(offset: widget.controller.text.length); _typed = widget.controller.text; },
    fieldViewBuilder: (context, controller, focus, submit) => TextField(key: Key('demo-${widget.fieldKey}'), controller: controller, focusNode: focus, onTapOutside: (_) => focus.unfocus(), onChanged: (value) => _typed = value, onTap: () => _typed = controller.text, onSubmitted: (_) { _typed = controller.text; submit(); }, style: const TextStyle(fontSize: 14), decoration: InputDecoration(labelText: widget.label, hintText: widget.hint, suffixIcon: IconButton(tooltip: '${widget.label} 지우기', onPressed: () { controller.clear(); _typed = ''; }, icon: const Icon(Icons.clear, size: 16)))),
    optionsViewBuilder: (context, select, options) => Material(elevation: 5, borderRadius: BorderRadius.circular(8), child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 200), child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: options.map((name) => ListTile(dense: true, title: Text(name, style: const TextStyle(fontSize: 14)), onTap: () => select(name))).toList()))),
  );
}
