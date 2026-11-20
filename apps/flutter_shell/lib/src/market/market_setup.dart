import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../serverless/client.dart';

const marketOrderedProducts=<String,String>{
  'general-tomato':'일반토마토',
  'chal-tomato':'찰토마토',
  'date-cherry-tomato':'대추방울',
  'paprika':'파프리카',
  'eggplant':'가지',
  'red-pepper':'홍고추',
  'green-pepper':'풋고추',
  'cucumber-baekdadagi':'백다다기',
  'onion':'양파',
  'cabbage':'양배추',
  'broccoli':'브로콜리',
};

const marketStandardMarkets=<Map<String,String>>[
  {'code':'110001','name':'서울가락'},
  {'code':'110008','name':'서울강서'},
  {'code':'210001','name':'부산엄궁'},
  {'code':'210009','name':'부산반여'},
  {'code':'220001','name':'대구북부'},
  {'code':'230001','name':'인천남촌'},
  {'code':'240001','name':'광주각화'},
  {'code':'240004','name':'광주서부'},
  {'code':'250001','name':'대전오정'},
  {'code':'250003','name':'대전노은'},
  {'code':'311201','name':'구리'},
  {'code':'320301','name':'강릉'},
  {'code':'350101','name':'전주'},
  {'code':'380101','name':'창원팔용'},
];

class MarketPreferences {
  MarketPreferences({
    this.defaultMarketCode='110001',
    this.defaultProduct='general-tomato',
    Set<String>? visibleProducts,
    this.trendDays=14,
    this.preferPerKg=true,
    this.autoExpandGrades=false,
    this.showMonthlyTrend=true,
  }):visibleProducts=visibleProducts??marketOrderedProducts.keys.toSet();

  String defaultMarketCode;
  String defaultProduct;
  Set<String> visibleProducts;
  int trendDays;
  bool preferPerKg;
  bool autoExpandGrades;
  bool showMonthlyTrend;

  static MarketPreferences current=MarketPreferences();
  static void reset()=>current=MarketPreferences();
}

class MarketSetupPage extends StatefulWidget {
  const MarketSetupPage({super.key,required this.client,this.onAuthError,this.canManage=true});
  final AppsScriptPlatformClient client;
  final Future<void> Function(Object)? onAuthError;
  final bool canManage;
  @override
  State<MarketSetupPage> createState()=>_MarketSetupPageState();
}
class _MarketSetupPageState extends State<MarketSetupPage> {
  final _market=TextEditingController(text:'110001');
  final _items=<String,Map<String,dynamic>>{};
  final _choices=<String,String>{};
  final _operation=const Uuid().v4();
  Map<String,dynamic>? _settings,_pendingSave;
  bool _busy=false,_allowHttp=false,_started=false,_dailyWarm=false;
  int? _next=1;
  int _scanned=0;
  String _error='';

  late String _prefMarketCode;
  late String _prefDefaultProduct;
  late Set<String> _prefVisible;
  late int _prefTrendDays;
  late bool _prefPerKg;
  late bool _prefAutoGrades;
  late bool _prefShowMonthly;

  static const products={'chal-tomato':'찰토마토','date-cherry-tomato':'대추방울토마토'};
  @override
  void initState(){
    super.initState();
    final p=MarketPreferences.current;
    _prefMarketCode=p.defaultMarketCode;
    _prefDefaultProduct=marketOrderedProducts.containsKey(p.defaultProduct)?p.defaultProduct:'general-tomato';
    _prefVisible=Set<String>.from(p.visibleProducts);
    _prefTrendDays=p.trendDays;
    _prefPerKg=p.preferPerKg;
    _prefAutoGrades=p.autoExpandGrades;
    _prefShowMonthly=p.showMonthlyTrend;
    if(widget.canManage){_load();}
  }
  void _applyPreferences(){
    if(_prefVisible.isEmpty){_prefVisible.add(_prefDefaultProduct);}
    if(!_prefVisible.contains(_prefDefaultProduct)){_prefDefaultProduct=_prefVisible.first;}
    MarketPreferences.current
      ..defaultMarketCode=_prefMarketCode
      ..defaultProduct=_prefDefaultProduct
      ..visibleProducts=Set<String>.from(_prefVisible)
      ..trendDays=_prefTrendDays
      ..preferPerKg=_prefPerKg
      ..autoExpandGrades=_prefAutoGrades
      ..showMonthlyTrend=_prefShowMonthly;
    Navigator.pop(context,true);
  }
  Future<void> _work(Future<void> Function() run) async {
    if(_busy){return;}setState((){_busy=true;_error='';});
    try{await run();}catch(e){if(e is PlatformAuthFailure&&const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(e.code)){await widget.onAuthError?.call(e);}if(mounted){setState(()=>_error=e is PlatformAuthFailure?e.message:'연결 설정을 확인하지 못했습니다.');}}
    finally{if(mounted){setState(()=>_busy=false);}}
  }
  Future<void> _load()=>_work(() async {final data=await widget.client.call('market.settings');if(mounted){setState((){_settings=data;_market.text=data['marketCode'] as String? ?? '110001';_allowHttp=data['allowPlainHttp']==true;_dailyWarm=data['dailyWarmEnabled']==true;});}});
  Future<void> _toggleDailyWarm(bool enabled)=>_work(() async {
    final res=await widget.client.call('market.warm',params:{'enabled':enabled,'marketCode':_prefMarketCode});
    if(mounted){setState((){_settings=res;_dailyWarm=res['dailyWarmEnabled']==true;});}
  });
  Future<void> _discover()=>_work(() async {
    final result=await widget.client.call('market.catalogue',params:{'marketCode':_market.text.trim(),'start':_next,'allowPlainHttp':_allowHttp});
    if(!mounted){return;}setState((){for(final item in List<Map<String,dynamic>>.from(result['items'] as List)){_items[item['id'] as String]=item;}_scanned+=result['scanned'] as int;_next=result['nextStart'] as int?;_started=true;});
  });
  Future<void> _save()=>_work(() async {
    _pendingSave??={'operationId':_operation,'expectedVersion':_settings!['version'],'confirmMapping':true,'allowPlainHttp':_allowHttp,'receipts':{for(final p in products.keys)p:_items[_choices[p]]!['receipt']}};
    await widget.client.call('market.configure',params:_pendingSave);if(mounted){Navigator.pop(context,true);}
  });
  @override
  void dispose(){_market.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>PopScope(canPop:!_busy,child:Scaffold(
    appBar:AppBar(title:const Text('농산물 시세 설정'),actions:[
      TextButton(key:const Key('market-prefs-apply'),onPressed:_busy?null:_applyPreferences,child:const Text('설정 적용')),
      if(widget.canManage)TextButton(key:const Key('market-setup-save'),onPressed:_busy||_choices.length!=2||_settings==null?null:_save,child:const Text('연결 저장')),
    ]),
    body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      if(_busy)const LinearProgressIndicator(),
      if(_error.isNotEmpty)Padding(padding:const EdgeInsets.only(bottom:12),child:Text(_error,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      const Text('시세 조회 기본 설정',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold)),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(
        key:const Key('market-pref-market'),
        initialValue:_prefMarketCode,
        isExpanded:true,
        decoration:const InputDecoration(labelText:'기본 공영도매시장'),
        items:[for(final m in marketStandardMarkets)DropdownMenuItem(value:m['code']!,child:Text('${m['name']} (${m['code']})'))],
        onChanged:(v){if(v!=null){setState(()=>_prefMarketCode=v);}},
      ),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(
        key:const Key('market-pref-default-product'),
        initialValue:_prefDefaultProduct,
        isExpanded:true,
        decoration:const InputDecoration(labelText:'시세 화면 첫 시작 품목'),
        items:[for(final e in marketOrderedProducts.entries)DropdownMenuItem(value:e.key,child:Text(e.value))],
        onChanged:(v){if(v!=null){setState((){_prefDefaultProduct=v;_prefVisible.add(v);});}},
      ),
      const SizedBox(height:14),
      const Text('일별 시세 추이 그래프 기간',style:TextStyle(fontSize:13,fontWeight:FontWeight.w600)),
      const SizedBox(height:6),
      Wrap(spacing:8,children:[
        for(final days in const [(7,'최근 1주 (7일)'),(14,'최근 2주 (14일)'),(21,'최근 3주 (21일)')])
          ChoiceChip(key:ValueKey('market-pref-days-${days.$1}'),label:Text(days.$2),selected:_prefTrendDays==days.$1,onSelected:(_)=>setState(()=>_prefTrendDays=days.$1)),
      ]),
      const SizedBox(height:14),
      const Text('대표 가격 표시 기준',style:TextStyle(fontSize:13,fontWeight:FontWeight.w600)),
      const SizedBox(height:6),
      Wrap(spacing:8,children:[
        ChoiceChip(key:const Key('market-pref-unit-kg'),label:const Text('kg당 단가(원/kg) 우선'),selected:_prefPerKg,onSelected:(_)=>setState(()=>_prefPerKg=true)),
        ChoiceChip(key:const Key('market-pref-unit-pkg'),label:const Text('규격(상자)당 경락가 우선'),selected:!_prefPerKg,onSelected:(_)=>setState(()=>_prefPerKg=false)),
      ]),
      SwitchListTile(
        key:const Key('market-pref-auto-grades'),
        contentPadding:EdgeInsets.zero,
        title:const Text('등급별·규격별 평균가 자동 펼치기'),
        subtitle:const Text('시세 화면을 열 때 등급별 가격표를 바로 펼쳐서 표시합니다.'),
        value:_prefAutoGrades,
        onChanged:(v)=>setState(()=>_prefAutoGrades=v),
      ),
      SwitchListTile(
        key:const Key('market-pref-monthly-trend'),
        contentPadding:EdgeInsets.zero,
        title:const Text('KAMIS 월별 시세 추이 그래프 표시'),
        subtitle:const Text('일별 시세 추이 아래에 최근 12개월 월평균 도매 시세를 함께 표시합니다.'),
        value:_prefShowMonthly,
        onChanged:(v)=>setState(()=>_prefShowMonthly=v),
      ),
      const Divider(height:24),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        const Text('상단 빠른 선택 품목 관리',style:TextStyle(fontSize:15,fontWeight:FontWeight.bold)),
        TextButton(onPressed:()=>setState(()=>_prefVisible=marketOrderedProducts.keys.toSet()),child:const Text('전체 선택')),
      ]),
      const Text('자주 보는 품목 탭에 표시할 작물을 선택하세요.',style:TextStyle(fontSize:12)),
      const SizedBox(height:6),
      Wrap(spacing:6,runSpacing:4,children:[
        for(final e in marketOrderedProducts.entries)
          FilterChip(
            key:ValueKey('market-pref-crop-${e.key}'),
            label:Text(e.value),
            selected:_prefVisible.contains(e.key),
            onSelected:(selected){
              setState((){
                if(selected){_prefVisible.add(e.key);}
                else if(_prefVisible.length>1){_prefVisible.remove(e.key);}
              });
            },
          ),
      ]),
      const SizedBox(height:16),
      FilledButton.icon(key:const Key('market-prefs-save-button'),onPressed:_busy?null:_applyPreferences,icon:const Icon(Icons.check),label:const Text('시세 설정 저장 및 적용')),
      if(widget.canManage)...[
        const Divider(height:32),
        const Text('서버 API 코드 검증 · 연결 설정 (관리자)',style:TextStyle(fontSize:15,fontWeight:FontWeight.bold)),
        const SizedBox(height:8),
        SwitchListTile(
          key:const Key('market-daily-warm-switch'),
          contentPadding:EdgeInsets.zero,
          title:const Text('매일 오전 8시 서버 시세 사전 준비'),
          subtitle:const Text('아침 경매 정산 후 주요 11개 품목 시세를 서버 캐시에 미리 불러옵니다.'),
          value:_dailyWarm,
          onChanged:_busy||_settings==null?null:_toggleDailyWarm,
        ),
        const SizedBox(height:4),
        Text(_settings?['keyConfigured']==true?'서버에 API 이용키가 등록돼 있습니다.':'서버 이용키 등록을 확인해 주세요.'),
        const Padding(padding:EdgeInsets.symmetric(vertical:8),child:Text('공식 품목 코드 API에서 사용 중인 품종을 찾아 연결합니다. 거래가 없는 날짜에도 품목 코드를 확인할 수 있습니다.',style:TextStyle(fontSize:12))),
        TextField(key:const Key('market-setup-code'),controller:_market,enabled:!_busy&&!_started,keyboardType:TextInputType.number,maxLength:6,decoration:const InputDecoration(labelText:'도매시장 코드',helperText:'110001 = 서울가락 (제공된 샘플 기준)')),
        CheckboxListTile(key:const Key('market-setup-http'),contentPadding:EdgeInsets.zero,title:const Text('제공처의 HTTP 연결 방식 확인'),subtitle:const Text('명세의 HTTP 주소로 서버의 API 이용키를 전송합니다. 암호화되지 않은 연결임을 확인하고 선택하세요.'),value:_allowHttp,onChanged:_busy||_started?null:(v)=>setState(()=>_allowHttp=v==true)),
        FilledButton.icon(key:const Key('market-discover'),onPressed:_busy||!_allowHttp||_settings?['keyConfigured']!=true||_next==null||_pendingSave!=null?null:_discover,icon:const Icon(Icons.search),label:Text(_started?'다음 코드에서 품목 찾기':'공식 코드에서 품목 찾기')),
        Text('조회한 코드 $_scanned건 · 찾은 토마토 분류 ${_items.length}개',style:const TextStyle(fontSize:12)),
        if(_started)TextButton(onPressed:_busy||_pendingSave!=null?null:()=>setState((){_started=false;_next=1;_scanned=0;_items.clear();_choices.clear();}),child:const Text('시장·분류 다시 선택')),
        for(final product in products.entries)...[
          Padding(padding:const EdgeInsets.only(top:12,bottom:6),child:Text('${product.value}에 연결할 실제 분류',style:const TextStyle(fontWeight:FontWeight.bold))),
          if(!_items.values.any((i)=>(i['eligible'] as List).contains(product.key)))const Text('현재 자료에서 정확히 해당하는 명칭을 찾지 못했습니다.',style:TextStyle(fontSize:12)),
          for(final item in _items.values.where((i)=>(i['eligible'] as List).contains(product.key)))ListTile(key:ValueKey('market-choice-${product.key}-${item['id']}'),dense:true,selected:_choices[product.key]==item['id'],leading:Icon(_choices[product.key]==item['id']?Icons.radio_button_checked:Icons.radio_button_off),title:Text('${item['category']} / ${item['variety']}'),subtitle:Text(item['id'] as String),onTap:_busy||_pendingSave!=null?null:()=>setState(()=>_choices[product.key]=item['id'] as String)),
        ],
        if(_items.isNotEmpty)ExpansionTile(title:const Text('조회된 다른 토마토 분류'),children:[for(final item in _items.values.where((i)=>(i['eligible'] as List).isEmpty))ListTile(dense:true,title:Text('${item['category']} / ${item['variety']}'),subtitle:Text(item['id'] as String))]),
      ],
    ]))),
  ));
}
