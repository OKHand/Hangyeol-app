import 'package:flutter/material.dart';
import '../serverless/client.dart';
import 'market_setup.dart';

const marketProducts={
  'chal-tomato':'찰토마토',
  'general-tomato':'일반토마토',
  'date-cherry-tomato':'대추방울',
  'paprika':'파프리카',
  'eggplant':'가지',
  'pepper':'고추',
  'cabbage':'양배추',
  'broccoli':'브로콜리',
};
const marketDefaultItems=<List<String>>[
  ['08','과일과채류','03','토마토','04','찰토마토'],
  ['08','과일과채류','03','토마토','01','토마토(일반)'],
  ['08','과일과채류','03','토마토','03','완숙토마토'],
  ['08','과일과채류','03','토마토','07','대저토마토'],
  ['08','과일과채류','03','토마토','99','기타토마토'],
  ['08','과일과채류','06','방울토마토','03','대추방울'],
  ['08','과일과채류','06','방울토마토','01','방울토마토'],
  ['08','과일과채류','06','방울토마토','02','송이토마토'],
  ['13','양채류','26','파프리카','03','빨강파프리카'],
  ['13','양채류','26','파프리카','02','노랑파프리카'],
  ['13','양채류','26','파프리카','04','오렌지파프리카'],
  ['13','양채류','26','파프리카','01','파프리카(일반)'],
  ['09','과채류','03','가지','01','가지(일반)'],
  ['12','조미채소류','05','풋고추','01','청양'],
  ['12','조미채소류','05','풋고추','10','오이고추'],
  ['12','조미채소류','05','풋고추','03','녹광'],
  ['12','조미채소류','05','풋고추','05','청초(일반)'],
  ['12','조미채소류','05','풋고추','02','청홍'],
  ['12','조미채소류','06','꽈리고추','01','꽈리고추(일반)'],
  ['12','조미채소류','08','홍고추','01','홍고추(일반)'],
  ['12','조미채소류','08','홍고추','02','홍청양'],
  ['10','엽경채류','04','양배추','01','양배추(일반)'],
  ['10','엽경채류','04','양배추','02','저장양배추'],
  ['10','엽경채류','04','양배추','05','꼬꼬마'],
  ['10','엽경채류','04','양배추','98','양배추(수입)'],
  ['13','양채류','06','브로코리(녹색꽃양배추)','01','브로코리(일반)'],
  ['13','양채류','06','브로코리(녹색꽃양배추)','02','뉴그린'],
  ['13','양채류','06','브로코리(녹색꽃양배추)','98','브로코리(수입)'],
  ['09','과채류','01','오이','02','백다다기'],
  ['09','과채류','01','오이','01','취청'],
  ['09','과채류','01','오이','03','가시오이'],
  ['09','과채류','01','오이','05','노각'],
  ['09','과채류','02','호박','01','애호박'],
  ['09','과채류','02','호박','02','쥬키니호박'],
  ['09','과채류','02','호박','04','풋호박'],
  ['09','과채류','02','호박','05','단호박'],
  ['13','양채류','02','피망(단고추)','01','피망(일반)'],
  ['13','양채류','02','피망(단고추)','02','홍피망'],
  ['13','양채류','02','피망(단고추)','05','청피망'],
  ['08','과일과채류','01','수박','01','수박(일반)'],
  ['08','과일과채류','02','참외','00','참외'],
  ['08','과일과채류','04','딸기','06','장희'],
  ['08','과일과채류','05','메론','01','네트계'],
  ['10','엽경채류','01','배추','01','봄배추'],
  ['10','엽경채류','02','얼갈이배추','01','얼갈이배추'],
  ['10','엽경채류','05','상추','04','적포기'],
  ['10','엽경채류','06','열무','01','열무(일반)'],
  ['10','엽경채류','08','시금치','00','시금치'],
  ['10','엽경채류','10','부추','01','일반부추'],
  ['10','엽경채류','11','깻잎','01','깻잎(일반)'],
  ['11','근채류','01','무','05','저장무'],
  ['11','근채류','03','당근','01','당근(일반)'],
  ['12','조미채소류','01','양파','08','조생양파'],
  ['12','조미채소류','02','대파','01','대파(일반)'],
  ['12','조미채소류','03','쪽파','01','쪽파(일반)'],
  ['12','조미채소류','09','마늘','42','깐마늘 대서'],
  ['12','조미채소류','10','생강','05','원강'],
  ['13','양채류','01','양상추','03','양상추(일반)'],
  ['13','양채류','04','셀러리(양미나리)','01','셀러리(일반)'],
  ['13','양채류','07','케일','01','쌈케일'],
  ['13','양채류','12','칼리플라워(꽃양배추)','01','칼리플라워(일반)'],
  ['13','양채류','14','콜라비(순무양배추)','01','콜라비(일반)'],
  ['13','양채류','15','아스파라가스','01','녹색'],
  ['13','양채류','28','로메인','01','로메인(일반)'],
];
const marketSampleDate='2026-11-10';
// Invented demonstration trades, never presented as official/current prices.
Map<String,dynamic> marketSample(String product,{String? label}){
  final name=label??marketProducts[product]??product;
  return {
    'product':product,'date':marketSampleDate,'sample':true,'source':'화면 체험용 가상 자료','fetchedAt':'','total':3,'truncated':false,
    'quotes':List.generate(3,(i){final cherry=product=='date-cherry-tomato',kg=cherry?3:5,price=(cherry?18000:14000)+i*2000;return <String,dynamic>{'id':'sample-$product-$i','product':product,'productName':name,'date':marketSampleDate,'market':i==2?'예시 도매시장 B':'예시 도매시장 A','grade':i==1?'상':'특','package':'${kg}kg 상자','price':price,'currency':'KRW','quantity':10+i*5,'weightKg':kg,'pricePerKg':price/kg};}),
  };
}
String marketMoney(num value)=>value.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'),(m)=>'${m[1]},');
String marketDay(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

class MarketPricesPage extends StatefulWidget {
  const MarketPricesPage({super.key,this.client,this.onAuthError,this.canManage=false});
  final bool canManage;
  final AppsScriptPlatformClient? client;
  final Future<void> Function(Object)? onAuthError;
  @override
  State<MarketPricesPage> createState()=>_MarketPricesPageState();
}
class _MarketPricesPageState extends State<MarketPricesPage> {
  String _product='chal-tomato',_customLabel='',_market='',_error='',_codeError='',_largeFilter='',_searchQuery='';
  Map<String,String>? _codeParams;
  final _searchController=TextEditingController();
  late List<Map<String,String>> _catalogue;
  late bool _sample;
  late DateTime _date;
  Map<String,dynamic>? _data;
  bool _loading=false,_syncingCodes=false;
  int _generation=0;
  int? _nextCodeStart=1;
  @override
  void initState(){
    super.initState();
    _catalogue=[for(final r in marketDefaultItems){'id':'${r[0]}:${r[2]}:${r[4]}','large':r[0],'largeName':r[1],'mid':r[2],'midName':r[3],'small':r[4],'goodName':r[5]}];
    _sample=widget.client==null;
    final kst=DateTime.now().toUtc().add(const Duration(hours:9));
    _date=DateTime(kst.year,kst.month,kst.day);
    _load();
  }
  Future<void> _load() async {
    final generation=++_generation;setState((){_loading=true;_error='';_data=null;_market='';});
    try{
      final params=<String,dynamic>{'product':_product,'date':marketDay(_date),if(_codeParams!=null)..._codeParams!};
      final result=_sample?marketSample(_product,label:_customLabel.isEmpty?null:_customLabel):await widget.client!.call('market.prices',params:params);
      if(!mounted||generation!=_generation){return;}
      if(result['sample']!=_sample||result['product']!=_product||result['date']!=(_sample?marketSampleDate:marketDay(_date))||result['quotes'] is! List){throw PlatformAuthFailure('MARKET_RESPONSE_INVALID','조회 조건과 응답이 일치하지 않습니다.');}
      setState(()=>_data=result);
    }catch(e){
      if(!mounted||generation!=_generation){return;}
      if(e is PlatformAuthFailure&&const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(e.code)){await widget.onAuthError?.call(e);}
      if(mounted&&generation==_generation){setState(()=>_error=e is PlatformAuthFailure?e.message:'시세를 불러오지 못했습니다. 다시 확인해 주세요.');}
    }finally{if(mounted&&generation==_generation){setState(()=>_loading=false);}}
  }
  Future<void> _syncCatalogue() async {
    if(_syncingCodes||widget.client==null){return;}
    setState((){_syncingCodes=true;_codeError='';});
    try{
      final result=await widget.client!.call('market.items',params:{'sync':true,'start':_nextCodeStart??1});
      if(!mounted){return;}
      final map={for(final item in _catalogue)item['id']!:item};
      for(final raw in List<Map<String,dynamic>>.from(result['items'] as List? ?? [])){
        final id=raw['id'] as String? ?? '';
        if(id.isNotEmpty){map[id]={'id':id,'large':'${raw['large']??''}','largeName':'${raw['largeName']??''}','mid':'${raw['mid']??''}','midName':'${raw['midName']??''}','small':'${raw['small']??''}','goodName':'${raw['goodName']??''}'};}
      }
      setState((){_catalogue=map.values.toList();_nextCodeStart=result['nextStart'] as int?;});
    }catch(e){
      if(!mounted){return;}
      if(e is PlatformAuthFailure&&const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(e.code)){await widget.onAuthError?.call(e);}
      if(mounted){setState(()=>_codeError=e is PlatformAuthFailure?e.message:'품목 코드 API를 불러오지 못했습니다.');}
    }finally{if(mounted){setState(()=>_syncingCodes=false);}}
  }
  void _selectPreset(String key){
    setState((){_product=key;_customLabel='';_codeParams=null;});
    _load();
  }
  void _selectCode({required String large,required String mid,required String midName,String small='',String goodName=''}){
    final id=small.isEmpty?'$large:$mid':'$large:$mid:$small';
    final label=small.isEmpty?'$midName (전체)':(midName==goodName?goodName:'$midName · $goodName');
    setState((){_product=id;_customLabel=label;_codeParams={'large':large,'mid':mid,if(small.isNotEmpty)'small':small,'productName':label};});
    _load();
  }
  Future<void> _chooseDate() async {
    final kst=DateTime.now().toUtc().add(const Duration(hours:9));
    final value=await showDatePicker(context:context,initialDate:_date,firstDate:DateTime(2010),lastDate:DateTime(kst.year,kst.month,kst.day));
    if(value!=null&&mounted){setState(()=>_date=value);await _load();}
  }
  @override
  void dispose(){_generation++;_searchController.dispose();super.dispose();}
  Widget _catalogueSection(){
    final lclasses=<String,String>{for(final item in _catalogue)item['large']!:item['largeName']!};
    final q=_searchQuery.trim().toLowerCase();
    final filtered=_catalogue.where((item){
      if(_largeFilter.isNotEmpty&&item['large']!=_largeFilter){return false;}
      if(q.isEmpty){return true;}
      return '${item['largeName']} ${item['midName']} ${item['goodName']} ${item['id']}'.toLowerCase().contains(q);
    }).toList();
    final byMid=<String,List<Map<String,String>>>{};
    for(final item in filtered){byMid.putIfAbsent('${item['large']}:${item['mid']}',()=>[]).add(item);}
    return ExpansionTile(
      key:const Key('market-catalogue-panel'),
      tilePadding:EdgeInsets.zero,
      title:Text('품목 코드로 전체 품목·품종 선택 (${_catalogue.length}개)',style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600)),
      subtitle:Text(_customLabel.isEmpty?'부류·품목·품종 검색 및 품목 코드 API 연동':'현재 선택: $_customLabel ($_product)',style:const TextStyle(fontSize:12)),
      children:[
        Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[
          Expanded(child:TextField(key:const Key('market-item-search'),controller:_searchController,onChanged:(v)=>setState(()=>_searchQuery=v),decoration:InputDecoration(labelText:'품목·품종·코드 검색',hintText:'예: 오이, 호박, 수박, 청양, 대저, 08:03',suffixIcon:_searchQuery.isEmpty?const Icon(Icons.search):IconButton(icon:const Icon(Icons.clear),onPressed:(){_searchController.clear();setState(()=>_searchQuery='');})))),
          if(widget.client!=null)...[
            const SizedBox(width:8),
            OutlinedButton.icon(key:const Key('market-sync-codes'),onPressed:_syncingCodes||_loading?null:_syncCatalogue,icon:const Icon(Icons.sync,size:16),label:Text(_syncingCodes?'불러오는 중…':'품목 코드 API')),
          ],
        ])),
        if(_codeError.isNotEmpty)Padding(padding:const EdgeInsets.only(bottom:8),child:Text(_codeError,style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.error))),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
          Padding(padding:const EdgeInsets.only(right:6),child:FilterChip(label:const Text('전체 부류'),selected:_largeFilter.isEmpty,onSelected:(_)=>setState(()=>_largeFilter=''))),
          for(final entry in lclasses.entries)Padding(padding:const EdgeInsets.only(right:6),child:FilterChip(label:Text('${entry.value}(${entry.key})'),selected:_largeFilter==entry.key,onSelected:(_)=>setState(()=>_largeFilter=_largeFilter==entry.key?'':entry.key))),
        ])),
        const SizedBox(height:8),
        ConstrainedBox(constraints:const BoxConstraints(maxHeight:260),child:ListView(shrinkWrap:true,children:[
          for(final group in byMid.entries)Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${group.value.first['largeName']} > ${group.value.first['midName']} (${group.key})',style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold)),
            const SizedBox(height:4),
            Wrap(spacing:6,runSpacing:4,children:[
              ActionChip(key:ValueKey('market-code-${group.key}'),label:Text('${group.value.first['midName']} 전체'),onPressed:_loading?null:()=>_selectCode(large:group.value.first['large']!,mid:group.value.first['mid']!,midName:group.value.first['midName']!)),
              for(final item in group.value)ActionChip(key:ValueKey('market-code-${item['id']}'),label:Text('${item['goodName']} (${item['small']})'),onPressed:_loading?null:()=>_selectCode(large:item['large']!,mid:item['mid']!,midName:item['midName']!,small:item['small']!,goodName:item['goodName']!)),
            ]),
          ])),
        ])),
      ],
    );
  }
  @override
  Widget build(BuildContext context){
    final rows=List<Map<String,dynamic>>.from(_data?['quotes'] as List? ?? []),markets=rows.map((r)=>r['market'] as String).toSet().toList()..sort();
    final visible=rows.where((r)=>_market.isEmpty||r['market']==_market).toList();
    final stamp=DateTime.tryParse(_data?['fetchedAt'] as String? ?? '')?.toLocal();
    return Scaffold(appBar:AppBar(title:const Text('농산물 경매 시세'),actions:[if(widget.canManage&&widget.client!=null)IconButton(key:const Key('market-open-setup'),tooltip:'시세 품목 연결',onPressed:_loading?null:() async {final result=await Navigator.of(context).push<bool>(MaterialPageRoute(builder:(_)=>MarketSetupPage(client:widget.client!,onAuthError:widget.onAuthError)));if(result==true&&mounted){await _load();}},icon:const Icon(Icons.settings_outlined)),IconButton(key:const Key('market-refresh'),tooltip:'시세 다시 조회',onPressed:_loading?null:_load,icon:const Icon(Icons.refresh))]),body:SafeArea(child:ListView(padding:const EdgeInsets.all(12),children:[
      if(widget.client!=null)Wrap(spacing:8,children:[ChoiceChip(key:const Key('market-live'),label:const Text('실제 시세'),selected:!_sample,onSelected:_loading?null:(_){setState(()=>_sample=false);_load();}),ChoiceChip(key:const Key('market-sample'),label:const Text('예시 자료 보기'),selected:_sample,onSelected:_loading?null:(_){setState(()=>_sample=true);_load();})]),
      if(_sample)Container(key:const Key('market-sample-banner'),margin:const EdgeInsets.symmetric(vertical:8),padding:const EdgeInsets.all(12),color:Theme.of(context).colorScheme.surfaceContainerHighest,child:const Text('체험용 가상 가격입니다. 실제 시장 시세가 아닙니다.',style:TextStyle(fontWeight:FontWeight.bold))),
      Wrap(spacing:8,runSpacing:4,children:[
        for(final entry in marketProducts.entries)ChoiceChip(key:Key('market-product-${entry.key}'),label:Text(entry.value),selected:_product==entry.key,onSelected:_loading?null:(_)=>_selectPreset(entry.key)),
        if(!marketProducts.containsKey(_product)&&_customLabel.isNotEmpty)ChoiceChip(key:const Key('market-product-custom'),label:Text(_customLabel),selected:true,onSelected:null),
      ]),
      _catalogueSection(),
      Row(children:[const Icon(Icons.calendar_month_outlined,size:18),const SizedBox(width:6),Expanded(child:Text('거래일 ${_sample?marketSampleDate:marketDay(_date)}')),TextButton(onPressed:_sample||_loading?null:_chooseDate,child:const Text('날짜 변경'))]),
      if(_loading)const LinearProgressIndicator(),
      if(_error.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(_error,key:const Key('market-error'),style:TextStyle(color:Theme.of(context).colorScheme.error))),
      if(_data!=null)...[
        DropdownButtonFormField<String>(key:ValueKey('market-filter-$_product-$_sample'),initialValue:_market,isExpanded:true,decoration:const InputDecoration(labelText:'시장 선택'),items:[const DropdownMenuItem(value:'',child:Text('조회된 시장 전체')),for(final name in markets)DropdownMenuItem(value:name,child:Text(name))],onChanged:(v)=>setState(()=>_market=v??'')),
        Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text('${_data!['source']}\n${_sample?'고정 샘플 자료':stamp==null?'조회 시각 미상':'조회 시각 ${marketDay(stamp)} ${stamp.hour.toString().padLeft(2,'0')}:${stamp.minute.toString().padLeft(2,'0')}'}${_data!['cached']==true?' · 캐시 자료':''}',style:const TextStyle(fontSize:12))),
        if(_data!['truncated']==true)const Text('일부 거래만 조회했습니다. 전체 거래의 평균이나 전체 시장 가격으로 해석하지 마세요.'),
        Text('표시 ${visible.length}건 · ${_data!['priceBasis']=='unconfirmed'?'제공가격의 단가 기준 확인이 필요합니다.':'가격은 해당 거래의 규격당 낙찰가입니다.'}',style:const TextStyle(fontSize:12)),
        if(visible.isEmpty)Padding(padding:const EdgeInsets.all(20),child:Text(_data!['truncated']==true?'조회한 일부 거래에서 해당 품목을 찾지 못했습니다. 전체 거래에 자료가 없다는 의미는 아닙니다.':'해당 거래일의 자료가 없습니다. 휴장·수집 지연일 수 있으니 다른 날짜도 확인하세요.')),
        for(final row in visible)Card(key:ValueKey('market-quote-${row['id']}'),margin:const EdgeInsets.symmetric(vertical:4),child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text(row['market'] as String,style:const TextStyle(fontWeight:FontWeight.bold)),
          Text('${row['productName']} · ${row['grade']} · ${row['package']}',style:const TextStyle(fontSize:13)),
          Text('${marketMoney(row['price'] as num)}원${row['priceBasis']=='unconfirmed'?' (제공가격)':' / ${row['package']}'}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
          if(row['pricePerKg'] is num)Text('kg당 ${marketMoney(row['pricePerKg'] as num)}원',style:const TextStyle(fontSize:12)),
          if(row['company'] is String)Text('${row['company']} · ${row['auctionTime']??''}',style:const TextStyle(fontSize:12)),
          Text('거래 수량 ${row['quantity']??'미제공'}${row['quantityUnitConfirmed']==false?' (단위 미확인)':''} · ${row['date']}',style:const TextStyle(fontSize:12)),
        ]))),
      ],
      const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('같은 품목이라도 등급·포장 중량이 다르면 가격이 다릅니다. 개별 거래를 단순 평균해 대표 시세로 표시하지 않습니다.',style:TextStyle(fontSize:12))),
    ])));
  }
}
