import 'demo_fixtures.g.dart';

String demoNumber(num value) {
  if (value.abs() < 0.000005) { return '0'; }
  final raw = value.toStringAsFixed(5).replaceFirst(RegExp(r'\.?0+$'), '');
  final parts = raw.split('.');
  parts[0] = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return parts.join('.');
}
String demoDay(DateTime value) => '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String demoNormalize(String text) => text.replaceAll(RegExp(r'\s+'), '').toLowerCase();
List<String> demoTokens(String text) => text.split(RegExp('[,，]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();
const demoModes = ['입고', '출고', '통합', '요약', '집계', '재고'];
const _rates = {'KRW': 1, 'USD': 1400, 'EUR': 1600, 'JPY': 9.5, 'CNY': 200};
const _system = ['합계', '전기이월', '잔액조정', '입금', '출금'];
class DemoEntry {
  DemoEntry(this.side, this.row);
  final String side;
  final List<Object?> row;
  String s(int col) => row[col]?.toString() ?? '';
  num n(int col) => num.tryParse(s(col).replaceAll(',', '')) ?? 0;
  DateTime get date => DateTime.parse(s(0));
  bool get snapshot => s(1) == '잔액' || s(5) == '전기이월' || s(5) == '잔액조정';
  String get currency => _rates.containsKey(s(11)) ? s(11) : 'KRW';
}
final demoEntries = (demoFixture['entries'] as List).map((v) => DemoEntry(v['side'] as String, List<Object?>.from(v['row'] as List))).toList();
final _header = List<String>.from(demoFixture['header'] as List);
class DemoReport {
  const DemoReport(this.columns, this.rows, {this.title});
  final String? title;
  final List<String> columns;
  final List<List<String>> rows;
  String csv() {
    String cell(String value) {
      final safe = RegExp(r'^[=+@\-]').hasMatch(value) && num.tryParse(value.replaceAll(',', '')) == null ? "'$value" : value;
      return '"${safe.replaceAll('"', '""')}"';
    }
    return [columns, ...rows].map((r) => r.map(cell).join(',')).join('\r\n');
  }
}
class DemoQuery {
  const DemoQuery({this.mode = '출고', this.customer = '', this.item = '', this.div = '', this.sales = '', this.origin = '', this.view = 'A', this.groupBy = 'detail', this.start, this.end});
  final String mode, customer, item, div, sales, origin, view, groupBy;
  final DateTime? start, end;
  bool _field(String value, String query, {bool partial = false}) {
    final tokens = demoTokens(query);
    return tokens.isEmpty || tokens.any((q) => partial ? demoNormalize(value).contains(demoNormalize(q)) : value == q);
  }
  bool _matches(DemoEntry r) => _field(r.s(2), customer, partial: true) && _field(r.s(1), div) && _field(r.s(3), item) && _field(r.s(4), origin, partial: true) && _field(r.s(5), sales, partial: true);
  bool _period(DemoEntry r) => (start == null || !r.date.isBefore(start!)) && (end == null || !r.date.isAfter(end!));
  List<String> suggestions(String field) {
    final col = {'customer': 2, 'div': 1, 'item': 3, 'sales': 5, 'origin': 4}[field]!;
    final values = demoEntries.where((r) => mode != '입고' && mode != '출고' || r.side == mode).map((r) => r.s(col)).where((s) => s.isNotEmpty).toSet().toList()..sort();
    return values;
  }
  DemoReport report() {
    if (!demoModes.contains(mode)) { throw ArgumentError('조회 유형을 확인해 주세요.'); }
    if (start != null && end != null && start!.isAfter(end!)) { throw ArgumentError('시작일이 종료일보다 늦습니다.'); }
    if (mode == '재고') { return _inventory(); }
    final matched = demoEntries.where(_matches).toList();
    if (mode == '요약') { return _summary(matched); }
    if (mode == '집계') { return _aggregate(matched.where(_period).toList()); }
    return _ledger(matched.where((r) => mode == '통합' || r.side == mode).toList());
  }
  String _display(Object? value) => value is num ? demoNumber(value) : value?.toString() ?? '';
  DemoReport _out(List<String> columns, List<List<Object?>> rows) => DemoReport(columns, rows.map((r) => r.map(_display).toList()).toList());
  DemoReport _ledger(List<DemoEntry> records) {
    records.sort((a, b) {
      final date = a.date.compareTo(b.date);
      if (date != 0) { return date; }
      if (mode != '통합') { return demoEntries.indexOf(a).compareTo(demoEntries.indexOf(b)); }
      final sa = ['전기이월', '잔액조정'].contains(a.s(5));
      final sb = ['전기이월', '잔액조정'].contains(b.s(5));
      final snap = (sb ? 1 : 0) - (sa ? 1 : 0);
      if (snap != 0) { return snap; }
      if (a.side != b.side) { return a.side == '입고' ? -1 : 1; }
      return demoEntries.indexOf(a).compareTo(demoEntries.indexOf(b));
    });
    final balances = <String, num>{};
    void apply(DemoEntry r) {
      final key = '${mode == '통합' ? r.side : ''}:${r.currency}';
      balances[key] = ['전기이월', '잔액조정'].contains(r.s(5)) ? r.n(14) : (balances[key] ?? 0) + r.n(14);
    }
    for (final r in records.where((r) => start != null && r.date.isBefore(start!))) {
      if (r.s(5) != '합계') { apply(r); }
    }
    final rows = <List<Object?>>[];
    for (final r in records.where(_period)) {
      final values = r.row.take(15).toList();
      if (mode == '통합' && r.side == '출고') {
        for (final col in [8, 9, 14]) { values[col] = -r.n(col); }
      }
      Object balance = '';
      if (r.s(5) != '합계') {
        apply(r);
        balance = balances.entries.fold<num>(0, (sum, e) {
          final parts = e.key.split(':');
          final sign = mode == '통합' && parts[0] == '출고' ? -1 : 1;
          return sum + sign * e.value * _rates[parts.last]!;
        });
      }
      rows.add([...values, balance, r.s(15), r.s(16)]);
    }
    return _out([..._header.take(15), mode == '통합' ? '통합잔액(KRW환산)' : '잔액(KRW환산)', ..._header.skip(15)], rows);
  }
  DemoReport _summary(List<DemoEntry> records) {
    final columns = ['거래처', '입고 기초잔액', '매입액', '출금액', '입고 조정액', '입고 잔액', '출고 기초잔액', '매출액', '입금액', '출고 조정액', '출고 잔액', '거래건수', '최근 거래일', '경과일수(일)'];
    final groups = <String, List<DemoEntry>>{};
    for (final r in records.where((r) => r.s(5) != '합계')) { groups.putIfAbsent(r.s(2), () => []).add(r); }
    final names = groups.keys.toList()..sort();
    final rows = <List<Object?>>[];
    for (final name in names) {
      final events = groups[name]!..sort((a, b) => a.date.compareTo(b.date) != 0 ? a.date.compareTo(b.date) : (b.snapshot ? 1 : 0) - (a.snapshot ? 1 : 0));
      num inBalance = 0, outBalance = 0, purchase = 0, withdraw = 0, inAdj = 0, sale = 0, deposit = 0, outAdj = 0;
      var count = 0;
      DateTime? last;
      void apply(DemoEntry r, bool period) {
        final amount = r.n(14);
        if (r.side == '입고') {
          if (r.snapshot) { if (period) { inAdj += amount - inBalance; } inBalance = amount; }
          else { inBalance += amount; if (period) { if (r.s(1) == '출금') { withdraw += amount; } else { purchase += amount; } } }
        } else {
          if (r.snapshot) { if (period) { outAdj += amount - outBalance; } outBalance = amount; }
          else { outBalance += amount; if (period) { if (r.s(1) == '입금') { deposit += amount; } else { sale += amount; } } }
        }
        if (period) { count++; last = r.date; }
      }
      for (final r in events.where((r) => start != null && r.date.isBefore(start!) && (end == null || !r.date.isAfter(end!)))) { apply(r, false); }
      final beginIn = -inBalance, beginOut = outBalance;
      for (final r in events.where(_period)) { apply(r, true); }
      final values = <Object?>[name, beginIn, -purchase, -withdraw, -inAdj, beginIn-purchase-withdraw-inAdj, beginOut, sale, deposit, outAdj, beginOut+sale+deposit+outAdj, count, last == null ? '-' : demoDay(last!).replaceAll('-', '.'), last == null ? '' : DateTime.parse(demoFixture['referenceDay'] as String).difference(last!).inDays];
      if (values.sublist(1, 11).any((v) => v != 0)) { rows.add(values); }
    }
    if (rows.isNotEmpty) { rows.add(['[ 총 합 계 ]', ...List.generate(11, (i) => rows.fold<num>(0, (s, r) => s+(r[i+1] as num))), '', '']); }
    return _out(columns, rows);
  }
  (num, String) _unit(num value, String unit) {
    switch (unit.toLowerCase()) {
      case 'g': case 'gram': return (value / 1000, 'kg');
      case 'kg': case 'kilogram': return (value, 'kg');
      case 't': case 'ton': return (value * 1000, 'kg');
      case 'ml': case 'milliliter': return (value / 1000, 'L');
      case 'dl': case 'deciliter': return (value / 10, 'L');
      case 'l': case 'liter': return (value, 'L');
      default: return (value, unit);
    }
  }
  DemoReport _aggregate(List<DemoEntry> records) {
    final groups = <String, Map<String, List<num>>>{};
    for (final r in records) {
      if (_system.contains(r.s(5)) || (r.n(9) == 0 && r.n(8) == 0)) { continue; }
      final (amount, unit) = _unit(r.n(9) == 0 ? r.n(8) : r.n(9), r.s(10));
      final key = [r.s(3), r.s(4), r.s(5), unit].join('|');
      final values = groups.putIfAbsent(key, () => {}).putIfAbsent(r.s(2), () => [0, 0]);
      values[r.side == '입고' ? 0 : 1] += amount;
    }
    final keys = groups.keys.toList()..sort();
    final customers = groups.values.expand((r) => r.keys).toSet().toList()..sort();
    final rows = <List<Object?>>[];
    final columns = view == 'B' ? ['품목','원품종','판매품종',...customers.expand((c) => ['${c}_순입고','${c}_순출고']),'순입고 합계','순출고 합계','단위'] : view == 'C' ? ['거래처','품목','원품종','판매품종','순입고','순출고','단위'] : ['품목','원품종','판매품종','순입고','순출고','단위'];
    for (final key in keys) {
      final parts = key.split('|'), values = groups[key]!;
      final totalIn = values.values.fold<num>(0, (s, v) => s+v[0]), totalOut = values.values.fold<num>(0, (s, v) => s+v[1]);
      if (view == 'B') { rows.add([...parts.take(3), ...customers.expand((c) => (values[c] ?? [0,0]).map<Object>((v) => v == 0 ? '' : v)), totalIn, totalOut, parts[3]]); }
      else if (view == 'C') { for (final c in customers.where(values.containsKey)) { final v = values[c]!; rows.add([c,...parts.take(3),v[0] == 0 ? '' : v[0],v[1] == 0 ? '' : v[1],parts[3]]); } }
      else { rows.add([...parts.take(3), totalIn, totalOut, parts[3]]); }
    }
    if (view == 'C') { rows.sort((a,b) => a[0].toString().compareTo(b[0].toString()) != 0 ? a[0].toString().compareTo(b[0].toString()) : a[1].toString().compareTo(b[1].toString())); }
    return _out(columns, rows);
  }
  DemoReport _inventory() {
    final specView = view != '총량';
    final groups = <String, _Stock>{};
    void add(String item, String company, String origin, String sales, Object spec, String unit, num qty, num total, String totalUnit) {
      if (!specView) { final converted = _unit(total, totalUnit); total = converted.$1; totalUnit = converted.$2; }
      final key = [item, groupBy == 'origin' ? '' : sales, origin, if (specView) spec, if (specView) unit, if (!specView) totalUnit].join('|');
      final r = groups.putIfAbsent(key, () => _Stock(item, company, origin, sales, spec.toString(), unit, totalUnit));
      r.quantity += qty; r.total += total; r.names.add(sales);
      if (r.company.isEmpty) { r.company = company; }
    }
    final inventory = demoFixture['inventory'] as Map;
    for (final raw in (inventory['rows'] as List).skip(2)) {
      final r = raw as List;
      add(r[0] as String, r[1] as String, r[3] as String, r[2] as String, r[4] as Object, r[5] as String, r[6] as num, r[7] as num, r[8] as String);
    }
    for (final r in demoEntries.where((r) => r.s(0).compareTo('2026-10-31') > 0 && !_system.contains(r.s(5)))) {
      final sign = r.side == '입고' ? 1 : -1;
      add(r.s(3), '', r.s(4), r.s(5), r.row[6]!, r.s(7), sign*r.n(8), sign*r.n(9), r.s(10));
    }
    final values = groups.values.toList()..sort((a, b) {
      for (final diff in [a.item.compareTo(b.item),a.company.compareTo(b.company),a.origin.compareTo(b.origin),groupBy == 'origin' ? 0 : a.sales.compareTo(b.sales),a.spec.toString().compareTo(b.spec.toString())]) { if (diff != 0) { return diff; } }
      return 0;
    });
    final label = groupBy == 'origin' ? '판매품종명(병합)' : '판매품종명';
    return _out(specView ? ['품목','회사명','원품종명',label,'규격','규격단위','현재 수량','현재 총량','총량단위','비고'] : ['품목','회사명','원품종명',label,'현재 총량','단위','비고'], values.map((r) {
      final names = r.names.toList()..sort();
      return <Object?>[r.item,r.company,r.origin,groupBy == 'origin' ? names.join(', ') : r.sales,if (specView) r.spec,if (specView) r.unit,if (specView) r.quantity,r.total,r.totalUnit,(specView && r.quantity < 0 || r.total < 0) ? '⚠️ 음수 확인 필요' : ''];
    }).toList());
  }
}
class _Stock {
  _Stock(this.item, this.company, this.origin, this.sales, this.spec, this.unit, this.totalUnit);
  final String item, origin, sales, unit, totalUnit;
  String company;
  final Object spec;
  num quantity = 0, total = 0;
  final Set<String> names = {};
}
