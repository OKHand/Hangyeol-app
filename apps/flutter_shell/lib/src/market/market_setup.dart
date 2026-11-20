import 'package:flutter/material.dart';
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
  static const _primary=Color(0xff1e6247);
  static const _surfaceBg=Color(0xfff5f8f5);
  static const _cardBorder=Color(0xffdce5df);
  static const _chipSelected=Color(0xffe6f0ea);
  static const _mutedText=Color(0xff52685c);

  Map<String,dynamic>? _settings;
  bool _busy=false,_dailyWarm=false;
  String _error='';

  late String _prefMarketCode;
  late String _prefDefaultProduct;
  late Set<String> _prefVisible;
  late int _prefTrendDays;
  late bool _prefPerKg;
  late bool _prefAutoGrades;
  late bool _prefShowMonthly;

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
    if(_busy){return;}
    setState((){_busy=true;_error='';});
    try{
      await run();
    }catch(e){
      if(e is PlatformAuthFailure&&const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(e.code)){
        await widget.onAuthError?.call(e);
      }
      if(mounted){
        setState(()=>_error=e is PlatformAuthFailure?e.message:'설정을 확인하지 못했습니다. 다시 시도해 주세요.');
      }
    }finally{
      if(mounted){setState(()=>_busy=false);}
    }
  }

  Future<void> _load()=>_work(() async {
    final data=await widget.client.call('market.settings');
    if(mounted){
      setState((){
        _settings=data;
        _dailyWarm=data['dailyWarmEnabled']==true;
      });
    }
  });

  Future<void> _toggleDailyWarm(bool enabled)=>_work(() async {
    final res=await widget.client.call('market.warm',params:{'enabled':enabled,'marketCode':_prefMarketCode});
    if(mounted){
      setState((){
        _settings=res;
        _dailyWarm=res['dailyWarmEnabled']==true;
      });
    }
  });

  String _formatWarmAt(String raw){
    final dt=DateTime.tryParse(raw)?.toUtc().add(const Duration(hours:9));
    if(dt==null){return '';}
    final mm=dt.month.toString().padLeft(2,'0');
    final dd=dt.day.toString().padLeft(2,'0');
    final hh=dt.hour.toString().padLeft(2,'0');
    final min=dt.minute.toString().padLeft(2,'0');
    return '$mm.$dd $hh:$min';
  }

  InputDecoration _fieldDecoration(String label)=>InputDecoration(
    labelText:label,
    filled:true,
    fillColor:const Color(0xfff8faf8),
    isDense:true,
    contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:12),
    border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:_cardBorder)),
    enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:_cardBorder)),
  );

  Widget _sectionCard({required IconData icon,required String title,Widget? trailing,required List<Widget> children}){
    return Container(
      padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(
        color:Colors.white,
        borderRadius:BorderRadius.circular(14),
        border:Border.all(color:_cardBorder),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Row(children:[
          Icon(icon,size:18,color:_primary),
          const SizedBox(width:6),
          Expanded(child:Text(title,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w700,color:Color(0xff1b3a2b)))),
          if(trailing!=null)trailing,
        ]),
        const SizedBox(height:10),
        ...children,
      ]),
    );
  }

  Widget _styledChoice({required Key chipKey,required String label,required bool selected,required VoidCallback? onSelected}){
    return ChoiceChip(
      key:chipKey,
      label:Text(label),
      selected:selected,
      selectedColor:_chipSelected,
      backgroundColor:const Color(0xfff8faf8),
      side:BorderSide(color:selected?_primary:_cardBorder),
      labelStyle:TextStyle(fontSize:13,fontWeight:selected?FontWeight.w600:FontWeight.normal,color:selected?_primary:const Color(0xff233329)),
      onSelected:onSelected==null?null:(_)=>onSelected(),
    );
  }

  @override
  Widget build(BuildContext context){
    final warmStamp=_formatWarmAt('${_settings?['warmLastAt']??''}');
    return PopScope(
      canPop:!_busy,
      child:Scaffold(
        backgroundColor:_surfaceBg,
        appBar:AppBar(
          backgroundColor:_surfaceBg,
          surfaceTintColor:Colors.transparent,
          title:const Text('농산물 시세 설정',style:TextStyle(fontWeight:FontWeight.w600)),
          actions:[
            TextButton(
              key:const Key('market-prefs-apply'),
              onPressed:_busy?null:_applyPreferences,
              child:const Text('적용',style:TextStyle(fontWeight:FontWeight.w600)),
            ),
            const SizedBox(width:4),
          ],
        ),
        body:SafeArea(
          child:Align(
            alignment:Alignment.topCenter,
            child:ConstrainedBox(
              constraints:const BoxConstraints(maxWidth:680),
              child:SingleChildScrollView(
                padding:const EdgeInsets.fromLTRB(12,6,12,16),
                child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                  if(_busy)const Padding(padding:EdgeInsets.only(bottom:10),child:LinearProgressIndicator(minHeight:2)),
                  if(_error.isNotEmpty)Container(
                    margin:const EdgeInsets.only(bottom:10),
                    padding:const EdgeInsets.all(10),
                    decoration:BoxDecoration(color:const Color(0xfffff0f0),borderRadius:BorderRadius.circular(12),border:Border.all(color:Theme.of(context).colorScheme.error.withValues(alpha:0.35))),
                    child:Text(_error,style:TextStyle(fontSize:13,color:Theme.of(context).colorScheme.error)),
                  ),
                  _sectionCard(
                    icon:Icons.storefront_outlined,
                    title:'기본 조회 조건',
                    children:[
                      LayoutBuilder(builder:(context,constraints){
                        final marketField=DropdownButtonFormField<String>(
                          key:const Key('market-pref-market'),
                          initialValue:_prefMarketCode,
                          isExpanded:true,
                          decoration:_fieldDecoration('기본 공영도매시장'),
                          items:[for(final m in marketStandardMarkets)DropdownMenuItem(value:m['code']!,child:Text('${m['name']} (${m['code']})'))],
                          onChanged:(v){if(v!=null){setState(()=>_prefMarketCode=v);}},
                        );
                        final productField=DropdownButtonFormField<String>(
                          key:const Key('market-pref-default-product'),
                          initialValue:_prefDefaultProduct,
                          isExpanded:true,
                          decoration:_fieldDecoration('시세 화면 첫 시작 품목'),
                          items:[for(final e in marketOrderedProducts.entries)DropdownMenuItem(value:e.key,child:Text(e.value))],
                          onChanged:(v){if(v!=null){setState((){_prefDefaultProduct=v;_prefVisible.add(v);});}},
                        );
                        if(constraints.maxWidth>=480){
                          return Row(children:[Expanded(child:marketField),const SizedBox(width:10),Expanded(child:productField)]);
                        }
                        return Column(children:[marketField,const SizedBox(height:10),productField]);
                      }),
                    ],
                  ),
                  const SizedBox(height:10),
                  _sectionCard(
                    icon:Icons.insights_outlined,
                    title:'화면 및 차트 표시',
                    children:[
                      const Text('일별 시세 추이 기간',style:TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:Color(0xff233329))),
                      const SizedBox(height:6),
                      Wrap(spacing:6,runSpacing:6,children:[
                        for(final days in const [(7,'최근 1주 (7일)'),(14,'최근 2주 (14일)'),(21,'최근 3주 (21일)')])
                          _styledChoice(
                            chipKey:ValueKey('market-pref-days-${days.$1}'),
                            label:days.$2,
                            selected:_prefTrendDays==days.$1,
                            onSelected:()=>setState(()=>_prefTrendDays=days.$1),
                          ),
                      ]),
                      const SizedBox(height:10),
                      const Text('대표 가격 표시 기준',style:TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:Color(0xff233329))),
                      const SizedBox(height:6),
                      Wrap(spacing:6,runSpacing:6,children:[
                        _styledChoice(
                          chipKey:const Key('market-pref-unit-kg'),
                          label:'kg당 단가(원/kg) 우선',
                          selected:_prefPerKg,
                          onSelected:()=>setState(()=>_prefPerKg=true),
                        ),
                        _styledChoice(
                          chipKey:const Key('market-pref-unit-pkg'),
                          label:'규격(상자)당 경락가 우선',
                          selected:!_prefPerKg,
                          onSelected:()=>setState(()=>_prefPerKg=false),
                        ),
                      ]),
                      const Divider(height:18,color:Color(0xffe7eee9)),
                      SwitchListTile(
                        key:const Key('market-pref-auto-grades'),
                        contentPadding:EdgeInsets.zero,
                        visualDensity:VisualDensity.compact,
                        title:const Text('등급별·규격별 평균가 자동 펼치기',style:TextStyle(fontSize:14,fontWeight:FontWeight.w500)),
                        subtitle:const Text('시세 화면을 열 때 등급별 가격표를 바로 펼쳐서 표시합니다.',style:TextStyle(fontSize:12,color:_mutedText)),
                        value:_prefAutoGrades,
                        onChanged:(v)=>setState(()=>_prefAutoGrades=v),
                      ),
                      SwitchListTile(
                        key:const Key('market-pref-monthly-trend'),
                        contentPadding:EdgeInsets.zero,
                        visualDensity:VisualDensity.compact,
                        title:const Text('KAMIS 월별 시세 추이 그래프 표시',style:TextStyle(fontSize:14,fontWeight:FontWeight.w500)),
                        subtitle:const Text('일별 시세 추이 아래에 최근 12개월 월평균 도매 시세를 함께 표시합니다.',style:TextStyle(fontSize:12,color:_mutedText)),
                        value:_prefShowMonthly,
                        onChanged:(v)=>setState(()=>_prefShowMonthly=v),
                      ),
                    ],
                  ),
                  const SizedBox(height:10),
                  _sectionCard(
                    icon:Icons.eco_outlined,
                    title:'상단 빠른 선택 품목',
                    trailing:Row(mainAxisSize:MainAxisSize.min,children:[
                      Container(
                        padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
                        decoration:BoxDecoration(color:_chipSelected,borderRadius:BorderRadius.circular(12)),
                        child:Text('${_prefVisible.length}/${marketOrderedProducts.length}',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:_primary)),
                      ),
                      const SizedBox(width:4),
                      TextButton(
                        style:TextButton.styleFrom(visualDensity:VisualDensity.compact,padding:const EdgeInsets.symmetric(horizontal:8)),
                        onPressed:_busy?null:()=>setState(()=>_prefVisible=marketOrderedProducts.keys.toSet()),
                        child:const Text('전체 선택',style:TextStyle(fontSize:12)),
                      ),
                    ]),
                    children:[
                      const Text('시세 화면 상단 탭에 바로 표시할 작물을 선택하세요. (최소 1개)',style:TextStyle(fontSize:12,color:_mutedText)),
                      const SizedBox(height:8),
                      Wrap(spacing:6,runSpacing:6,children:[
                        for(final e in marketOrderedProducts.entries)
                          FilterChip(
                            key:ValueKey('market-pref-crop-${e.key}'),
                            label:Text(e.value),
                            selected:_prefVisible.contains(e.key),
                            selectedColor:_chipSelected,
                            backgroundColor:const Color(0xfff8faf8),
                            side:BorderSide(color:_prefVisible.contains(e.key)?_primary:_cardBorder),
                            labelStyle:TextStyle(fontSize:13,fontWeight:_prefVisible.contains(e.key)?FontWeight.w600:FontWeight.normal,color:_prefVisible.contains(e.key)?_primary:const Color(0xff233329)),
                            onSelected:(selected){
                              setState((){
                                if(selected){_prefVisible.add(e.key);}
                                else if(_prefVisible.length>1){_prefVisible.remove(e.key);}
                              });
                            },
                          ),
                      ]),
                    ],
                  ),
                  if(widget.canManage)...[
                    const SizedBox(height:10),
                    _sectionCard(
                      icon:Icons.schedule_outlined,
                      title:'관리자 · 서버 사전 준비',
                      trailing:_settings==null
                        ?null
                        :Container(
                          padding:const EdgeInsets.symmetric(horizontal:9,vertical:3),
                          decoration:BoxDecoration(
                            color:_settings?['keyConfigured']==true?const Color(0xffe6f4ea):const Color(0xfffff4e5),
                            borderRadius:BorderRadius.circular(12),
                          ),
                          child:Text(
                            _settings?['keyConfigured']==true?'API 연결됨':'이용키 확인 필요',
                            style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:_settings?['keyConfigured']==true?_primary:const Color(0xff8a5300)),
                          ),
                        ),
                      children:[
                        SwitchListTile(
                          key:const Key('market-daily-warm-switch'),
                          contentPadding:EdgeInsets.zero,
                          visualDensity:VisualDensity.compact,
                          title:const Text('매일 오전 8시 서버 시세 사전 준비',style:TextStyle(fontSize:14,fontWeight:FontWeight.w500)),
                          subtitle:const Text('아침 경매 정산 후 주요 11개 품목 시세를 서버 캐시에 미리 불러옵니다.',style:TextStyle(fontSize:12,color:_mutedText)),
                          value:_dailyWarm,
                          onChanged:_busy||_settings==null?null:_toggleDailyWarm,
                        ),
                        if(warmStamp.isNotEmpty)Padding(
                          padding:const EdgeInsets.only(top:6),
                          child:Text('마지막 사전 준비: $warmStamp (${_settings?['warmLastCount']??0}개 품목)',style:const TextStyle(fontSize:12,color:_mutedText)),
                        ),
                      ],
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
        bottomNavigationBar:Container(
          decoration:const BoxDecoration(color:Colors.white,border:Border(top:BorderSide(color:_cardBorder))),
          child:SafeArea(
            child:Center(
              heightFactor:1,
              child:ConstrainedBox(
                constraints:const BoxConstraints(maxWidth:680),
                child:Padding(
                  padding:const EdgeInsets.fromLTRB(16,10,16,12),
                  child:SizedBox(
                    width:double.infinity,
                    height:48,
                    child:FilledButton.icon(
                      key:const Key('market-prefs-save-button'),
                      onPressed:_busy?null:_applyPreferences,
                      style:FilledButton.styleFrom(
                        backgroundColor:_primary,
                        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
                      ),
                      icon:const Icon(Icons.check),
                      label:const Text('시세 설정 저장 및 적용',style:TextStyle(fontSize:15,fontWeight:FontWeight.w600)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
