import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../serverless/client.dart';
import 'market_setup.dart';

/// 매일 오전 8시(KST)를 기준으로 시세 일일 갱신 주기를 식별하는 날짜 키(`YYYY-MM-DD`).
String marketDailyCycleKey(DateTime utcOrLocal) {
  final shifted = utcOrLocal.toUtc().add(const Duration(hours: 9)).subtract(const Duration(hours: 8));
  final y = shifted.year.toString().padLeft(4, '0');
  final m = shifted.month.toString().padLeft(2, '0');
  final d = shifted.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

const marketProducts=marketOrderedProducts;
const marketDefaultMarkets=marketStandardMarkets;
const marketDefaultItems=<List<String>>[
  ['08','과일과채류','03','토마토','01','토마토(일반)'],
  ['08','과일과채류','03','토마토','04','찰토마토'],
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
  ['12','조미채소류','08','홍고추','01','홍고추(일반)'],
  ['12','조미채소류','08','홍고추','02','홍청양'],
  ['12','조미채소류','05','풋고추','01','청양'],
  ['12','조미채소류','05','풋고추','10','오이고추'],
  ['12','조미채소류','05','풋고추','03','녹광'],
  ['12','조미채소류','05','풋고추','05','청초(일반)'],
  ['12','조미채소류','05','풋고추','02','청홍'],
  ['12','조미채소류','06','꽈리고추','01','꽈리고추(일반)'],
  ['09','과채류','01','오이','02','백다다기'],
  ['09','과채류','01','오이','01','취청'],
  ['09','과채류','01','오이','03','가시오이'],
  ['09','과채류','01','오이','05','노각'],
  ['12','조미채소류','01','양파','08','조생양파'],
  ['10','엽경채류','04','양배추','01','양배추(일반)'],
  ['10','엽경채류','04','양배추','02','저장양배추'],
  ['10','엽경채류','04','양배추','05','꼬꼬마'],
  ['10','엽경채류','04','양배추','98','양배추(수입)'],
  ['13','양채류','06','브로코리(녹색꽃양배추)','01','브로코리(일반)'],
  ['13','양채류','06','브로코리(녹색꽃양배추)','02','뉴그린'],
  ['13','양채류','06','브로코리(녹색꽃양배추)','98','브로코리(수입)'],
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
double? _parseKg(String? pack){
  if(pack==null){return null;}
  final m=RegExp(r'^(\d+(?:\.\d+)?)\s*(kg|g)(?:\s*[가-힣A-Za-z]+)?$',caseSensitive:false).firstMatch(pack.trim());
  if(m==null){return null;}
  final v=double.tryParse(m.group(1)!)??0;
  return v<=0?null:(m.group(2)!.toLowerCase()=='g'?v/1000:v);
}
// Used only by the standalone offline demo app when no API client is supplied.
Map<String,dynamic> marketSample(String product,{String? label}){
  final name=label??(product=='date-cherry-tomato'?'대추방울토마토':marketProducts[product]??product);
  final cherry=product=='date-cherry-tomato',baseKg=cherry?3:5,basePrice=cherry?18000:14000;
  final quotes=List.generate(3,(i){final price=basePrice+i*2000;return <String,dynamic>{'id':'sample-$product-$i','product':product,'productName':name,'date':marketSampleDate,'market':i==2?'예시 도매시장 B':'예시 도매시장 A','grade':i==1?'상':'특','package':'${baseKg}kg 상자','price':price,'currency':'KRW','quantity':10+i*5,'weightKg':baseKg,'pricePerKg':price/baseKg};});
  final basePerKg=(basePrice+2000)/baseKg;
  final offsets=[-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0];
  final deltas=[-240,-180,-220,160,180,-120,-310,-150,-90,20,40,90,120,0];
  final trend=List.generate(offsets.length,(i){
    final d=DateTime.parse('${marketSampleDate}T00:00:00Z').add(Duration(days:offsets[i]));
    final mm=d.month.toString().padLeft(2,'0'),dd=d.day.toString().padLeft(2,'0');
    return <String,dynamic>{'date':'${d.year}-$mm-$dd','label':'$mm.$dd','avgPricePerKg':(basePerKg+deltas[i]).round(),'avgPackagePrice':basePrice+deltas[i]*baseKg,'totalWeightKg':45*baseKg};
  });
  final monthlyTrend=<String,dynamic>{
    'supported':true,
    'unit':'1kg',
    'unitLabel':'원/kg',
    'isPerKg':true,
    'regionName':'서울',
    'cropLabel':name,
    'source':'KAMIS 농산물유통정보 (예시)',
    'points':[
      for(var i=0;i<6;i++){'month':'2026-0${i+5}','label':'26.0${i+5}','avgPrice':(basePerKg+deltas[i]).round()},
    ],
  };
  return {
    'product':product,'date':marketSampleDate,'sample':true,'source':'화면 체험용 가상 자료','fetchedAt':'','total':3,'truncated':false,
    'quotes':quotes,'trend':trend,'monthlyTrend':monthlyTrend,
  };
}
String marketMoney(num value)=>value.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'),(m)=>'${m[1]},');
String marketDay(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

class MarketPricesPage extends StatefulWidget {
  const MarketPricesPage({
    super.key,
    this.client,
    this.onAuthError,
    this.canManage=false,
    this.email='',
    this.cacheDirectory,
    this.now,
    this.enablePrefetch=true,
  });
  final bool canManage;
  final AppsScriptPlatformClient? client;
  final Future<void> Function(Object)? onAuthError;
  final String email;
  final Directory? cacheDirectory;
  final DateTime Function()? now;
  final bool enablePrefetch;
  @override
  State<MarketPricesPage> createState()=>_MarketPricesPageState();
}
class _MarketPricesPageState extends State<MarketPricesPage> {
  static const _quoteChunkSize=30;
  late String _product,_marketCode;
  String _customLabel='',_market='',_error='',_codeError='',_largeFilter='',_searchQuery='';
  Map<String,String>? _codeParams;
  final _searchController=TextEditingController();
  final Map<String,Map<String,dynamic>> _memoryCache={};
  final Set<String> _prefetchedKeys={};
  late List<Map<String,String>> _catalogue;
  late List<Map<String,String>> _markets;
  late bool _sample;
  late DateTime _date;
  Map<String,dynamic>? _data;
  bool _loading=false,_loadingSummary=false,_loadingMoreQuotes=false,_loadingTrend=false,_loadingMonthly=false,_syncingCodes=false,_showGrades=false,_fromCache=false,_supportsStagedLoading=false,_prefetching=false,_dirResolved=false;
  Directory? _resolvedDir;
  int _generation=0,_trendLoadedBatches=0,_totalTrendBatches=3,_prefetchDone=0,_prefetchTotal=0,_prefetchToken=0,_loadedTrendDays=0,_writesSincePrune=0;
  int? _nextCodeStart=1;
  @override
  void initState(){
    super.initState();
    final prefs=MarketPreferences.current;
    _product= prefs.defaultProduct;
    _marketCode=prefs.defaultMarketCode;
    _showGrades=prefs.autoExpandGrades;
    _catalogue=[for(final r in marketDefaultItems){'id':'${r[0]}:${r[2]}:${r[4]}','large':r[0],'largeName':r[1],'mid':r[2],'midName':r[3],'small':r[4],'goodName':r[5]}];
    _markets=[for(final m in marketDefaultMarkets){'code':m['code']!,'name':m['name']!}];
    _sample=widget.client==null;
    final kst=_now().add(const Duration(hours:9));
    _date=DateTime(kst.year,kst.month,kst.day);
    _load();
  }
  DateTime _now()=>(widget.now??DateTime.now)().toUtc();
  String _cacheKey(String product,String dateStr)=>'$_marketCode:$product:$dateStr';
  String _fileNameFor(String key)=>'${sha256.convert(utf8.encode(key))}.json';

  Future<Directory?> _resolveCacheDir() async {
    if(_dirResolved){return _resolvedDir;}
    if(widget.cacheDirectory!=null){
      _resolvedDir=widget.cacheDirectory;
      _dirResolved=true;
      return _resolvedDir;
    }
    if(widget.email.isEmpty){_dirResolved=true;return null;}
    try{
      final docs=await getApplicationDocumentsDirectory().timeout(const Duration(seconds:1));
      final keyHash=sha256.convert(utf8.encode('${widget.client?.storageKey??'offline'}:${widget.email}')).toString();
      _resolvedDir=Directory('${docs.path}${Platform.pathSeparator}hangyeol_market${Platform.pathSeparator}$keyHash');
    }catch(_){_resolvedDir=null;}
    _dirResolved=true;
    return _resolvedDir;
  }

  Future<void> _restoreMeta() async {
    if(_supportsStagedLoading){return;}
    try{
      final dir=await _resolveCacheDir();
      if(dir==null||!dir.existsSync()){return;}
      final f=File('${dir.path}${Platform.pathSeparator}_meta.json');
      if(!f.existsSync()){return;}
      final decoded=jsonDecode(f.readAsStringSync());
      if(decoded is Map&&decoded['stagedSupported']==true&&mounted){_supportsStagedLoading=true;}
    }catch(_){}
  }

  Future<void> _persistMeta() async {
    try{
      final dir=await _resolveCacheDir();
      if(dir==null){return;}
      if(!dir.existsSync()){dir.createSync(recursive:true);}
      final f=File('${dir.path}${Platform.pathSeparator}_meta.json');
      f.writeAsStringSync(jsonEncode({'stagedSupported':true}),flush:true);
    }catch(_){}
  }

  Future<Map<String,dynamic>?> _readDiskCache(String cacheKey) async {
    try{
      final dir=await _resolveCacheDir();
      if(dir==null||!dir.existsSync()){return null;}
      final f=File('${dir.path}${Platform.pathSeparator}${_fileNameFor(cacheKey)}');
      if(!f.existsSync()){return null;}
      final decoded=jsonDecode(f.readAsStringSync());
      return decoded is Map<String,dynamic>?decoded:Map<String,dynamic>.from(decoded as Map);
    }catch(_){return null;}
  }

  Future<void> _writeDiskCache(String cacheKey,Map<String,dynamic> entry) async {
    try{
      final dir=await _resolveCacheDir();
      if(dir==null){return;}
      if(!dir.existsSync()){dir.createSync(recursive:true);}
      final f=File('${dir.path}${Platform.pathSeparator}${_fileNameFor(cacheKey)}');
      f.writeAsStringSync(jsonEncode(entry),flush:true);
      _writesSincePrune++;
      if(_writesSincePrune<20){return;}
      _writesSincePrune=0;
      final files=<({File file,DateTime modified})>[];
      for(final ent in dir.listSync(followLinks:false)){
        if(ent is File&&ent.path.endsWith('.json')&&!ent.path.endsWith('${Platform.pathSeparator}_meta.json')){
          files.add((file:ent,modified:ent.statSync().modified));
        }
      }
      if(files.length>120){
        files.sort((a,b)=>a.modified.compareTo(b.modified));
        for(final old in files.take(files.length-120)){
          try{old.file.deleteSync();}catch(_){}
        }
      }
    }catch(_){}
  }

  bool _isEntryFresh(Map<String,dynamic>? entry,String product,String dateStr,String currentCycle,MarketPreferences prefs){
    if(entry==null||entry['complete']!=true||entry['data'] is! Map){return false;}
    final data=entry['data'] as Map;
    if(data['product']!=product||data['date']!=dateStr){return false;}
    if(((entry['trendDays'] as num?)?.toInt()??0)<prefs.trendDays){return false;}
    if(prefs.showMonthlyTrend&&data['monthlyTrend']==null){return false;}
    final kstNow=_now().add(const Duration(hours:9));
    final todayKst=marketDay(DateTime(kstNow.year,kstNow.month,kstNow.day));
    if(dateStr.compareTo(todayKst)<0){return true;}
    return entry['cycleKey']==currentCycle;
  }

  Future<void> _saveCompletedCache({required String product,required String dateStr,required String cycleKey,required MarketPreferences prefs,required Map<String,dynamic> dataSnapshot}) async {
    final snapshot=Map<String,dynamic>.from(dataSnapshot)
      ..['summaryOnly']=false
      ..['quotesPending']=false
      ..['nextPage']=null
      ..['trendPending']=false
      ..['monthlyTrendPending']=false;
    final entry=<String,dynamic>{
      'cycleKey':cycleKey,
      'complete':true,
      'trendDays':prefs.trendDays,
      'savedAt':_now().toIso8601String(),
      'data':snapshot,
    };
    final key=_cacheKey(product,dateStr);
    _memoryCache[key]=entry;
    await _writeDiskCache(key,entry);
  }

  Future<void> _load({bool forceRefresh=false}) async {
    final generation=++_generation;
    _prefetchToken++;
    final prefs=MarketPreferences.current;
    final dateStr=_sample?marketSampleDate:marketDay(_date);
    final currentCycle=marketDailyCycleKey(_now());
    final cacheKey=_cacheKey(_product,dateStr);
    if(!_sample&&!forceRefresh){
      final memEntry=_memoryCache[cacheKey];
      if(_isEntryFresh(memEntry,_product,dateStr,currentCycle,prefs)){
        final cachedData=Map<String,dynamic>.from(memEntry!['data'] as Map);
        setState((){
          _data=cachedData;
          _loading=false;
          _loadingSummary=false;
          _loadingMoreQuotes=false;
          _loadingTrend=false;
          _loadingMonthly=false;
          _fromCache=true;
          _prefetching=false;
          _error='';
          _market='';
          _loadedTrendDays=(memEntry['trendDays'] as num?)?.toInt()??prefs.trendDays;
        });
        unawaited(_startBackgroundPrefetch(dateStr,currentCycle));
        return;
      }
      setState((){_loading=true;_loadingSummary=false;_loadingMoreQuotes=false;_loadingTrend=false;_loadingMonthly=false;_fromCache=false;_prefetching=false;_trendLoadedBatches=0;_error='';_data=null;_market='';});
      await _restoreMeta();
      if(!mounted||generation!=_generation){return;}
      final diskEntry=await _readDiskCache(cacheKey);
      if(!mounted||generation!=_generation){return;}
      if(_isEntryFresh(diskEntry,_product,dateStr,currentCycle,prefs)){
        final cachedData=Map<String,dynamic>.from(diskEntry!['data'] as Map);
        _memoryCache[cacheKey]=diskEntry;
        setState((){
          _data=cachedData;
          _loading=false;
          _loadingSummary=false;
          _loadingMoreQuotes=false;
          _loadingTrend=false;
          _loadingMonthly=false;
          _fromCache=true;
          _prefetching=false;
          _error='';
          _market='';
          _loadedTrendDays=(diskEntry['trendDays'] as num?)?.toInt()??prefs.trendDays;
        });
        unawaited(_startBackgroundPrefetch(dateStr,currentCycle));
        return;
      }
    }

    if(_sample||!_supportsStagedLoading){
      setState((){_loading=true;_loadingSummary=false;_loadingMoreQuotes=false;_loadingTrend=false;_loadingMonthly=false;_fromCache=false;_prefetching=false;_trendLoadedBatches=0;_error='';_data=null;_market='';});
      try{
        final params=<String,dynamic>{
          'product':_product,
          'date':dateStr,
          'summaryOnly':true,
          'includeTrend':true,
          'progressive':true,
          'page':1,
          if(_marketCode!='110001')'marketCode':_marketCode,
          if(_codeParams!=null)..._codeParams!,
          if(forceRefresh)'refresh':true,
        };
        final result=_sample?marketSample(_product,label:_customLabel.isEmpty?null:_customLabel):await widget.client!.call('market.prices',params:params);
        if(!mounted||generation!=_generation){return;}
        if(result['sample']!=_sample||result['product']!=_product||result['date']!=dateStr||result['quotes'] is! List){throw PlatformAuthFailure('MARKET_RESPONSE_INVALID','조회 조건과 응답이 일치하지 않습니다.');}
        if(result['summaryOnly']==true){
          _supportsStagedLoading=true;
          unawaited(_persistMeta());
        }
        final copy=Map<String,dynamic>.from(result);
        setState((){_data=copy;_loading=false;});
        if(!_sample&&widget.client!=null){
          unawaited(_loadProgressive(generation,copy,dateStr,currentCycle,forceRefresh:forceRefresh));
        }
      }catch(e){
        if(!mounted||generation!=_generation){return;}
        if(e is PlatformAuthFailure&&const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(e.code)){await widget.onAuthError?.call(e);}
        if(mounted&&generation==_generation){setState(()=>_error=e is PlatformAuthFailure?e.message:'시세를 불러오지 못했습니다. 다시 확인해 주세요.');}
      }finally{if(mounted&&generation==_generation&&_loading){setState(()=>_loading=false);}}
      return;
    }

    // 지원 확인된 서버: 첫 화면부터 평균 시세(상단) + 일별/월별 추이 차트를 동시 시작하고, 개별 경락가는 평균 시세 뒤 순차 로딩
    final batches=_buildTrendBatches(prefs.trendDays);
    final shellData=<String,dynamic>{
      'product':_product,
      'productName':_customLabel.isEmpty?(marketProducts[_product]??_product):_customLabel,
      'date':dateStr,
      'quotes':<Map<String,dynamic>>[],
      'trend':<Map<String,dynamic>>[],
      'summary':<String,dynamic>{},
      'source':'농식품 공공데이터 포털 경매정보',
      'fetchedAt':'',
      'sample':false,
      'cached':false,
      'priceBasis':'unconfirmed',
      'truncated':false,
    };
    setState((){
      _loading=false;
      _loadingSummary=true;
      _loadingTrend=true;
      _loadingMonthly=prefs.showMonthlyTrend;
      _loadingMoreQuotes=true;
      _fromCache=false;
      _prefetching=false;
      _trendLoadedBatches=0;
      _totalTrendBatches=batches.length;
      _error='';
      _market='';
      _data=shellData;
    });
    await _runParallelStagedLoad(generation,dateStr,currentCycle,batches,prefs,forceRefresh:forceRefresh);
  }

  Future<void> _runParallelStagedLoad(int generation,String dateStr,String currentCycle,List<List<int>> batches,MarketPreferences prefs,{bool forceRefresh=false}) async {
    var fatalError=false;
    Map<String,dynamic>? resolvedMeta;
    Future<void> fetchSummaryThenQuotes() async {
      var nextPage=1;
      try{
        final sumRes=await widget.client!.call('market.prices',params:{
          'product':_product,
          'date':dateStr,
          'summaryOnly':true,
          if(_marketCode!='110001')'marketCode':_marketCode,
          if(_codeParams!=null)..._codeParams!,
          if(forceRefresh)'refresh':true,
        });
        if(!mounted||generation!=_generation||_data==null){return;}
        if(sumRes['sample']!=false||sumRes['product']!=_product||sumRes['date']!=dateStr||sumRes['quotes'] is! List){
          throw PlatformAuthFailure('MARKET_RESPONSE_INVALID','조회 조건과 응답이 일치하지 않습니다.');
        }
        resolvedMeta=Map<String,dynamic>.from(sumRes);
        final initialQuotes=List<Map<String,dynamic>>.from(sumRes['quotes'] as List? ?? []);
        nextPage=sumRes['summaryOnly']==true?((sumRes['nextPage'] as int?)??1):(sumRes['nextPage'] as int? ?? 0);
        setState((){
          _loadingSummary=false;
          _data={
            ..._data!,
            'productName':sumRes['productName']??_data!['productName'],
            'large':sumRes['large'],
            'mid':sumRes['mid'],
            'small':sumRes['small'],
            'summary':sumRes['summary']??_data!['summary'],
            'source':sumRes['source']??_data!['source'],
            'fetchedAt':sumRes['fetchedAt']??_data!['fetchedAt'],
            'priceBasis':sumRes['priceBasis']??_data!['priceBasis'],
            'cached':sumRes['cached']??_data!['cached'],
            if(initialQuotes.isNotEmpty)'quotes':initialQuotes,
            if(nextPage<=0)'truncated':sumRes['truncated']??false,
          };
        });
      }catch(e){
        fatalError=true;
        if(!mounted||generation!=_generation){return;}
        if(e is PlatformAuthFailure&&const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(e.code)){await widget.onAuthError?.call(e);}
        if(mounted&&generation==_generation){
          setState((){
            _loadingSummary=false;
            _loadingMoreQuotes=false;
            _error=e is PlatformAuthFailure?e.message:'시세를 불러오지 못했습니다. 다시 확인해 주세요.';
          });
        }
        return;
      }

      var curPage=nextPage;
      while(curPage>0&&mounted&&generation==_generation){
        final pageToFetch=curPage;
        curPage=0;
        try{
          final res=await widget.client!.call('market.prices',params:{
            'product':_product,
            'date':dateStr,
            'progressive':true,
            'page':pageToFetch,
            'chunkSize':_quoteChunkSize,
            if(_marketCode!='110001')'marketCode':_marketCode,
            if(_codeParams!=null)..._codeParams!,
            if(forceRefresh)'refresh':true,
          });
          if(!mounted||generation!=_generation||_data==null){return;}
          final existing=List<Map<String,dynamic>>.from(_data!['quotes'] as List? ?? []);
          final incoming=List<Map<String,dynamic>>.from(res['quotes'] as List? ?? []);
          final seen={for(final q in existing)'${q['id']}'};
          for(final q in incoming){if(seen.add('${q['id']}')){existing.add(q);}}
          curPage=(res['nextPage'] as int?)??0;
          setState((){
            _data={
              ..._data!,
              'quotes':existing,
              'truncated':res['truncated']??_data!['truncated'],
              if((_data!['fetchedAt'] as String? ?? '').isEmpty)'fetchedAt':res['fetchedAt']??'',
            };
          });
        }catch(_){fatalError=true;break;}
      }
      if(mounted&&generation==_generation){setState(()=>_loadingMoreQuotes=false);}
    }

    Future<void> fetchTrendBatches() async {
      for(final offsets in batches){
        if(!mounted||generation!=_generation){return;}
        final dates=[for(final off in offsets)marketDay(_date.add(Duration(days:off)))];
        try{
          final res=await widget.client!.call('market.prices',params:{
            'product':_product,
            'date':dateStr,
            'trendBatch':true,
            'dates':dates,
            if(resolvedMeta?['large'] is String)'large':resolvedMeta!['large'],
            if(resolvedMeta?['mid'] is String)'mid':resolvedMeta!['mid'],
            if(resolvedMeta?['small'] is String)'small':resolvedMeta!['small'],
            if(_marketCode!='110001')'marketCode':_marketCode,
            if(_codeParams!=null)..._codeParams!,
            if(forceRefresh)'refresh':true,
          });
          if(!mounted||generation!=_generation||_data==null){return;}
          final incoming=List<Map<String,dynamic>>.from(res['points'] as List? ?? []);
          final current=List<Map<String,dynamic>>.from(_data!['trend'] as List? ?? []);
          final merged=<String,Map<String,dynamic>>{
            for(final p in current)if(p['date'] is String)p['date'] as String:p,
            for(final p in incoming)if(p['date'] is String)p['date'] as String:p,
          };
          final sorted=merged.values.toList()..sort((a,b)=>'${a['date']}'.compareTo('${b['date']}'));
          setState((){
            _trendLoadedBatches++;
            _data={..._data!,'trend':sorted};
          });
        }catch(_){}
      }
      if(mounted&&generation==_generation){setState(()=>_loadingTrend=false);}
    }

    Future<void> fetchMonthlyTrend() async {
      if(!prefs.showMonthlyTrend){return;}
      try{
        final res=await widget.client!.call('market.prices',params:{
          'product':_product,
          'date':dateStr,
          'monthlyTrend':true,
          'months':12,
          if(resolvedMeta?['large'] is String)'large':resolvedMeta!['large'],
          if(resolvedMeta?['mid'] is String)'mid':resolvedMeta!['mid'],
          if(resolvedMeta?['small'] is String)'small':resolvedMeta!['small'],
          if(_marketCode!='110001')'marketCode':_marketCode,
          if(_codeParams!=null)..._codeParams!,
          if(forceRefresh)'refresh':true,
        });
        if(!mounted||generation!=_generation||_data==null){return;}
        setState((){_data={..._data!,'monthlyTrend':res};});
      }catch(_){}
      if(mounted&&generation==_generation){setState(()=>_loadingMonthly=false);}
    }

    await Future.wait([fetchSummaryThenQuotes(),fetchTrendBatches(),fetchMonthlyTrend()]);
    if(!mounted||generation!=_generation||fatalError||_data==null){return;}
    _loadedTrendDays=prefs.trendDays;
    await _saveCompletedCache(product:_product,dateStr:dateStr,cycleKey:currentCycle,prefs:prefs,dataSnapshot:_data!);
    if(!mounted||generation!=_generation){return;}
    unawaited(_startBackgroundPrefetch(dateStr,currentCycle));
  }

  List<List<int>> _buildTrendBatches(int days){
    final total=days.clamp(7,21);
    final offsets=[for(var d=-1;d>=-(total-1);d--)d];
    final batches=<List<int>>[];
    for(var i=0;i<offsets.length;i+=5){
      final chunk=offsets.sublist(i,math.min(i+5,offsets.length))..sort();
      batches.add(chunk);
    }
    return batches;
  }
  Future<void> _loadProgressive(int generation,Map<String,dynamic> firstPage,String dateStr,String currentCycle,{bool forceRefresh=false}) async {
    final prefs=MarketPreferences.current;
    final needTrend=firstPage['trendPending']==true;
    final needMonthly=prefs.showMonthlyTrend&&firstPage['monthlyTrend']==null&&(firstPage['trendPending']==true||firstPage['monthlyTrendPending']==true);
    var nextPage=firstPage['nextPage'] as int?;
    if(!needTrend&&!needMonthly&&nextPage==null){
      if(_supportsStagedLoading){
        _loadedTrendDays=prefs.trendDays;
        await _saveCompletedCache(product:_product,dateStr:dateStr,cycleKey:currentCycle,prefs:prefs,dataSnapshot:firstPage);
        if(mounted&&generation==_generation){unawaited(_startBackgroundPrefetch(dateStr,currentCycle));}
      }
      return;
    }
    final batches=_buildTrendBatches(prefs.trendDays);
    if(mounted&&generation==_generation){
      setState((){_loadingTrend=needTrend;_loadingMonthly=needMonthly;_totalTrendBatches=batches.length;_loadingMoreQuotes=nextPage!=null;});
    }
    Future<void> fetchMonthlyTrend() async {
      if(!needMonthly){return;}
      try{
        final res=await widget.client!.call('market.prices',params:{
          'product':_product,
          'date':dateStr,
          'monthlyTrend':true,
          'months':12,
          if(firstPage['large'] is String)'large':firstPage['large'],
          if(firstPage['mid'] is String)'mid':firstPage['mid'],
          if(firstPage['small'] is String)'small':firstPage['small'],
          if(_marketCode!='110001')'marketCode':_marketCode,
          if(_codeParams!=null)..._codeParams!,
          if(forceRefresh)'refresh':true,
        });
        if(!mounted||generation!=_generation||_data==null){return;}
        setState((){_data={..._data!,'monthlyTrend':res};});
      }catch(_){}
      if(mounted&&generation==_generation){setState(()=>_loadingMonthly=false);}
    }
    Future<void> fetchTrendBatches() async {
      if(!needTrend){return;}
      for(final offsets in batches){
        if(!mounted||generation!=_generation){return;}
        final dates=[for(final off in offsets)marketDay(_date.add(Duration(days:off)))];
        try{
          final res=await widget.client!.call('market.prices',params:{
            'product':_product,
            'date':dateStr,
            'trendBatch':true,
            'dates':dates,
            if(firstPage['large'] is String)'large':firstPage['large'],
            if(firstPage['mid'] is String)'mid':firstPage['mid'],
            if(firstPage['small'] is String)'small':firstPage['small'],
            if(_marketCode!='110001')'marketCode':_marketCode,
            if(_codeParams!=null)..._codeParams!,
            if(forceRefresh)'refresh':true,
          });
          if(!mounted||generation!=_generation||_data==null){return;}
          final incoming=List<Map<String,dynamic>>.from(res['points'] as List? ?? []);
          final current=List<Map<String,dynamic>>.from(_data!['trend'] as List? ?? []);
          final merged=<String,Map<String,dynamic>>{
            for(final p in current)if(p['date'] is String)p['date'] as String:p,
            for(final p in incoming)if(p['date'] is String)p['date'] as String:p,
          };
          final sorted=merged.values.toList()..sort((a,b)=>'${a['date']}'.compareTo('${b['date']}'));
          setState((){
            _trendLoadedBatches++;
            _data={..._data!,'trend':sorted};
          });
        }catch(_){}
      }
      if(mounted&&generation==_generation){setState(()=>_loadingTrend=false);}
    }
    Future<void> fetchRemainingQuotePages() async {
      while(nextPage!=null&&mounted&&generation==_generation){
        final pageToFetch=nextPage!;
        nextPage=null;
        try{
          final res=await widget.client!.call('market.prices',params:{
            'product':_product,
            'date':dateStr,
            'progressive':true,
            'page':pageToFetch,
            'chunkSize':_quoteChunkSize,
            if(_marketCode!='110001')'marketCode':_marketCode,
            if(_codeParams!=null)..._codeParams!,
            if(forceRefresh)'refresh':true,
          });
          if(!mounted||generation!=_generation||_data==null){return;}
          final existing=List<Map<String,dynamic>>.from(_data!['quotes'] as List? ?? []);
          final incoming=List<Map<String,dynamic>>.from(res['quotes'] as List? ?? []);
          final seen={for(final q in existing)'${q['id']}'};
          for(final q in incoming){if(seen.add('${q['id']}')){existing.add(q);}}
          nextPage=res['nextPage'] as int?;
          setState((){
            _data={..._data!,'quotes':existing,'truncated':res['truncated']??_data!['truncated']};
          });
        }catch(_){break;}
      }
      if(mounted&&generation==_generation){setState(()=>_loadingMoreQuotes=false);}
    }
    await Future.wait([fetchTrendBatches(),fetchMonthlyTrend(),fetchRemainingQuotePages()]);
    if(!mounted||generation!=_generation||_data==null){return;}
    if(_supportsStagedLoading){
      _loadedTrendDays=prefs.trendDays;
      await _saveCompletedCache(product:_product,dateStr:dateStr,cycleKey:currentCycle,prefs:prefs,dataSnapshot:_data!);
      if(mounted&&generation==_generation){unawaited(_startBackgroundPrefetch(dateStr,currentCycle));}
    }
  }

  Future<void> _startBackgroundPrefetch(String dateStr,String currentCycle) async {
    if(_sample||widget.client==null||!widget.enablePrefetch||!_supportsStagedLoading){return;}
    final dir=await _resolveCacheDir();
    if(dir==null){return;}
    final prefs=MarketPreferences.current;
    final runKey='$_marketCode:$dateStr:$currentCycle:${prefs.trendDays}:${prefs.showMonthlyTrend}:${prefs.visibleProducts.length}';
    if(_prefetchedKeys.contains(runKey)){return;}
    final token=_prefetchToken;
    final orderedVisible=<String>[
      for(final key in marketOrderedProducts.keys)
        if(prefs.visibleProducts.contains(key)&&key!=_product)key,
    ];
    final pending=<String>[];
    for(final key in orderedVisible){
      if(!mounted||token!=_prefetchToken){return;}
      final cKey=_cacheKey(key,dateStr);
      final cached=_memoryCache[cKey]??await _readDiskCache(cKey);
      if(!_isEntryFresh(cached,key,dateStr,currentCycle,prefs)){pending.add(key);}
    }
    if(pending.isEmpty){
      _prefetchedKeys.add(runKey);
      return;
    }
    if(!mounted||token!=_prefetchToken){return;}
    setState((){_prefetching=true;_prefetchDone=0;_prefetchTotal=pending.length;});
    final batches=_buildTrendBatches(prefs.trendDays);
    for(final prod in pending){
      if(!mounted||token!=_prefetchToken){break;}
      try{
        final baseParams=<String,dynamic>{
          'product':prod,
          'date':dateStr,
          if(_marketCode!='110001')'marketCode':_marketCode,
        };
        final sumFuture=widget.client!.call('market.prices',params:{...baseParams,'summaryOnly':true});
        final trendFuture=Future.wait([
          for(final offsets in batches)
            widget.client!.call('market.prices',params:{
              ...baseParams,
              'trendBatch':true,
              'dates':[for(final off in offsets)marketDay(_date.add(Duration(days:off)))],
            }),
        ]);
        final monthlyFuture=prefs.showMonthlyTrend
          ?widget.client!.call('market.prices',params:{...baseParams,'monthlyTrend':true,'months':12})
          :Future<Map<String,dynamic>?>.value(null);

        final results=await Future.wait<dynamic>([sumFuture,trendFuture,monthlyFuture]);
        if(!mounted||token!=_prefetchToken){break;}
        final sumRes=Map<String,dynamic>.from(results[0] as Map);
        final trendBatches=results[1] as List<Map<String,dynamic>>;
        final monthlyRes=results[2] as Map<String,dynamic>?;
        final trendMap=<String,Map<String,dynamic>>{};
        for(final b in trendBatches){
          for(final p in List<Map<String,dynamic>>.from(b['points'] as List? ?? [])){
            if(p['date'] is String){trendMap[p['date'] as String]=p;}
          }
        }
        final sortedTrend=trendMap.values.toList()..sort((a,b)=>'${a['date']}'.compareTo('${b['date']}'));

        final quotes=List<Map<String,dynamic>>.from(sumRes['quotes'] as List? ?? []);
        final seenIds={for(final q in quotes)'${q['id']}'};
        var nextPage=sumRes['summaryOnly']==true?((sumRes['nextPage'] as int?)??1):((sumRes['nextPage'] as int?)??0);
        var truncated=sumRes['truncated']==true;
        while(nextPage>0&&mounted&&token==_prefetchToken){
          final pageRes=await widget.client!.call('market.prices',params:{...baseParams,'progressive':true,'page':nextPage,'chunkSize':100});
          if(!mounted||token!=_prefetchToken){break;}
          for(final q in List<Map<String,dynamic>>.from(pageRes['quotes'] as List? ?? [])){
            if(seenIds.add('${q['id']}')){quotes.add(q);}
          }
          truncated=pageRes['truncated']==true;
          nextPage=(pageRes['nextPage'] as int?)??0;
        }
        if(!mounted||token!=_prefetchToken){break;}
        final fullData=<String,dynamic>{
          ...sumRes,
          'quotes':quotes,
          'trend':sortedTrend,
          if(monthlyRes!=null)'monthlyTrend':monthlyRes,
          'truncated':truncated,
        };
        await _saveCompletedCache(product:prod,dateStr:dateStr,cycleKey:currentCycle,prefs:prefs,dataSnapshot:fullData);
      }on PlatformAuthFailure catch(e){
        if(const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(e.code)){
          if(mounted&&token==_prefetchToken){setState(()=>_prefetching=false);}
          return;
        }
      }catch(_){}
      if(mounted&&token==_prefetchToken){setState(()=>_prefetchDone++);}
    }
    if(mounted&&token==_prefetchToken){
      _prefetchedKeys.add(runKey);
      setState(()=>_prefetching=false);
    }
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
      final mList=<Map<String,String>>[];
      for(final raw in List<Map<String,dynamic>>.from(result['markets'] as List? ?? [])){
        final code='${raw['code']??''}',name='${raw['name']??''}';
        if(code.isNotEmpty&&name.isNotEmpty){mList.add({'code':code,'name':name});}
      }
      setState((){
        _catalogue=map.values.toList();
        if(mList.isNotEmpty){_markets=mList;}
        _nextCodeStart=result['nextStart'] as int?;
      });
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
  Future<void> _openSettings() async {
    if(widget.client==null||_loading||_loadingSummary){return;}
    final beforeMarket=_marketCode;
    final result=await Navigator.of(context).push<bool>(MaterialPageRoute(builder:(_)=>MarketSetupPage(client:widget.client!,onAuthError:widget.onAuthError,canManage:widget.canManage)));
    if(result==true&&mounted){
      final p=MarketPreferences.current;
      final needReload=_marketCode!=p.defaultMarketCode||(!p.visibleProducts.contains(_product)&&_customLabel.isEmpty)||(p.showMonthlyTrend&&_data?['monthlyTrend']==null)||(_loadedTrendDays>0&&_loadedTrendDays<p.trendDays);
      setState((){
        _marketCode=p.defaultMarketCode;
        _showGrades=p.autoExpandGrades;
        if(!p.visibleProducts.contains(_product)&&_customLabel.isEmpty){
          _product=p.defaultProduct;
          _codeParams=null;
        }
      });
      if(needReload||beforeMarket!=_marketCode){await _load();}
    }
  }
  @override
  void dispose(){_generation++;_searchController.dispose();super.dispose();}
  Map<String,dynamic> _computeSummary(List<Map<String,dynamic>> visible){
    final serverSummary=_data?['summary'] is Map?Map<String,dynamic>.from(_data!['summary'] as Map):null;
    if(_market.isEmpty&&serverSummary!=null&&serverSummary['settlementSource']!=null){return serverSummary;}
    double totalKg=0,totalAmt=0,pkgAmt=0,pkgCnt=0,totalQty=0;
    final groups=<String,Map<String,dynamic>>{};
    for(final r in visible){
      final price=(r['price'] as num?)?.toDouble();
      if(price==null){continue;}
      final qty=((r['quantity'] as num?)??1).toDouble();
      final kg=((r['weightKg'] as num?)?.toDouble())??_parseKg(r['package'] as String?);
      totalQty+=qty;pkgAmt+=price*qty;pkgCnt+=qty;
      final rowKg=kg!=null&&kg>0?kg*qty:0.0,rowAmt=price*qty;
      if(rowKg>0){totalKg+=rowKg;totalAmt+=rowAmt;}
      final grade=(r['grade'] as String?)??'등급 미제공';
      final pack=(r['package'] as String?)??'';
      final key=(grade!='등급 미제공'?grade:pack).isEmpty?'기타':(grade!='등급 미제공'?grade:pack);
      final g=groups.putIfAbsent(key,()=>{'label':key,'grade':grade,'package':pack,'totalKg':0.0,'totalAmt':0.0,'pkgAmt':0.0,'count':0.0});
      g['count']=(g['count'] as double)+qty;
      g['pkgAmt']=(g['pkgAmt'] as double)+rowAmt;
      if(rowKg>0){g['totalKg']=(g['totalKg'] as double)+rowKg;g['totalAmt']=(g['totalAmt'] as double)+rowAmt;}
    }
    final groupList=[for(final g in groups.values){
      'label':g['label'],
      'avgPricePerKg':(g['totalKg'] as double)>0?((g['totalAmt'] as double)/(g['totalKg'] as double)).round():null,
      'avgPrice':(g['count'] as double)>0?((g['pkgAmt'] as double)/(g['count'] as double)).round():null,
      'totalWeightKg':(g['totalKg'] as double).round(),
      'quantity':(g['count'] as double).round(),
    }];
    return {
      'avgPricePerKg':totalKg>0?(totalAmt/totalKg).round():null,
      'totalWeightKg':totalKg.round(),
      'avgPackagePrice':pkgCnt>0?(pkgAmt/pkgCnt).round():null,
      'totalQuantity':totalQty.round(),
      'groups':groupList,
    };
  }
  Widget _dashboardSection(List<Map<String,dynamic>> visible){
    final prefs=MarketPreferences.current;
    final summary=_computeSummary(visible);
    final avgPerKg=summary['avgPricePerKg'] as int?;
    final avgPkg=summary['avgPackagePrice'] as int?;
    final totalKg=(summary['totalWeightKg'] as int?)??0;
    final totalQty=(summary['totalQuantity'] as int?)??0;
    final groups=List<Map<String,dynamic>>.from(summary['groups'] as List? ?? []);
    final rawTrend=List<Map<String,dynamic>>.from(_data?['trend'] as List? ?? []);
    final todayStr=_sample?marketSampleDate:marketDay(_date);
    final todayLabel=todayStr.substring(5).replaceAll('-','.');
    if((avgPerKg!=null||avgPkg!=null)&&!rawTrend.any((p)=>p['date']==todayStr)){
      rawTrend.add({'date':todayStr,'label':todayLabel,'avgPricePerKg':avgPerKg,'avgPackagePrice':avgPkg,'totalWeightKg':totalKg});
      rawTrend.sort((a,b)=>'${a['date']}'.compareTo('${b['date']}'));
    }
    final hasPerKg=avgPerKg!=null||rawTrend.any((p)=>p['avgPricePerKg'] is num);
    final usePerKg=prefs.preferPerKg?hasPerKg:(avgPkg==null&&hasPerKg);
    final chartPoints=<({String label,double value})>[
      for(final p in rawTrend)
        if((usePerKg?p['avgPricePerKg']:p['avgPackagePrice']) is num)
          (label:'${p['label']??''}',value:((usePerKg?p['avgPricePerKg']:p['avgPackagePrice']) as num).toDouble()),
    ];
    final primaryPrice=usePerKg&&avgPerKg!=null?'${marketMoney(avgPerKg)}원/kg':avgPkg!=null?'${marketMoney(avgPkg)}원':avgPerKg!=null?'${marketMoney(avgPerKg)}원/kg':'-';
    return Container(
      key:const Key('market-dashboard-card'),
      margin:const EdgeInsets.symmetric(vertical:8),
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:const Color(0xfff4f6f8),borderRadius:BorderRadius.circular(18)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        if(_loadingSummary)const Padding(padding:EdgeInsets.only(bottom:8),child:LinearProgressIndicator(minHeight:2)),
        Row(children:[
          Expanded(child:Container(
            key:const Key('market-avg-price-card'),
            padding:const EdgeInsets.symmetric(vertical:14,horizontal:12),
            decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),
            child:Column(children:[
              const Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.monetization_on,size:18,color:Color(0xfff59e0b)),SizedBox(width:4),Text('평균가격',style:TextStyle(fontSize:13,fontWeight:FontWeight.w600))]),
              const SizedBox(height:6),
              Text(_loadingSummary&&primaryPrice=='-'?'불러오는 중…':primaryPrice,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
            ]),
          )),
          const SizedBox(width:10),
          Expanded(child:Container(
            key:const Key('market-total-volume-card'),
            padding:const EdgeInsets.symmetric(vertical:14,horizontal:12),
            decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),
            child:Column(children:[
              const Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.local_shipping,size:18,color:Color(0xff3b82f6)),SizedBox(width:4),Text('거래량',style:TextStyle(fontSize:13,fontWeight:FontWeight.w600))]),
              const SizedBox(height:6),
              Text(_loadingSummary&&totalKg==0&&totalQty==0?'불러오는 중…':(totalKg>0?'${marketMoney(totalKg)}kg':totalQty>0?'${marketMoney(totalQty)}건':'0kg'),style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
            ]),
          )),
        ]),
        if(groups.isNotEmpty)...[
          const SizedBox(height:10),
          Material(color:Colors.white,borderRadius:BorderRadius.circular(12),child:InkWell(
            key:const Key('market-grade-breakdown'),
            borderRadius:BorderRadius.circular(12),
            onTap:()=>setState(()=>_showGrades=!_showGrades),
            child:Padding(padding:const EdgeInsets.symmetric(vertical:10,horizontal:14),child:Column(children:[
              Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                Text(summary['settlementSource']!=null?'등급별 평균가':'규격·등급별 평균가',style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600)),
                const SizedBox(width:4),
                Icon(_showGrades?Icons.expand_less:Icons.chevron_right,size:18),
              ]),
              if(_showGrades)...[
                const Divider(height:16),
                for(final g in groups)Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                  Text('${g['label']}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),
                  Text('${g['avgPricePerKg']!=null?'${marketMoney(g['avgPricePerKg'] as num)}원/kg · ':''}${g['avgPrice']!=null?'평균 ${marketMoney(g['avgPrice'] as num)}원':''}',style:const TextStyle(fontSize:12)),
                ])),
              ],
            ])),
          )),
        ],
        if(chartPoints.isNotEmpty||_loadingTrend)...[
          const SizedBox(height:12),
          Container(
            key:const Key('market-trend-chart'),
            padding:const EdgeInsets.fromLTRB(14,14,14,12),
            decoration:BoxDecoration(color:const Color(0xffe6f7f0),borderRadius:BorderRadius.circular(16)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Text('일별 시세 추이 (최근 ${prefs.trendDays}일)',textAlign:TextAlign.center,style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold,color:Color(0xff1b3a2b))),
              Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                Text(_loadingTrend?'일별 시세 추이 불러오는 중… ($_trendLoadedBatches/$_totalTrendBatches)':'조회 일수 ${chartPoints.length}일',style:const TextStyle(fontSize:11,color:Color(0xff2b7de9))),
                Text(usePerKg?'단위 : 원/kg':'단위 : 원',style:const TextStyle(fontSize:11,color:Color(0xff52685c))),
              ]),
              if(_loadingTrend)const Padding(padding:EdgeInsets.only(top:4),child:LinearProgressIndicator(minHeight:2)),
              if(chartPoints.isNotEmpty)...[
                const SizedBox(height:8),
                SizedBox(height:170,child:CustomPaint(painter:_MarketTrendPainter(points:chartPoints))),
              ],
            ]),
          ),
        ],
        if(prefs.showMonthlyTrend)...[
          _monthlyTrendSection(),
        ],
      ]),
    );
  }
  Widget _monthlyTrendSection(){
    final monthly=_data?['monthlyTrend'] is Map?Map<String,dynamic>.from(_data!['monthlyTrend'] as Map):null;
    final rawPoints=List<Map<String,dynamic>>.from(monthly?['points'] as List? ?? []);
    final mPoints=<({String label,double value})>[
      for(final p in rawPoints)
        if(p['avgPrice'] is num)
          (label:'${p['label']??p['month']??''}',value:(p['avgPrice'] as num).toDouble()),
    ];
    if(!_loadingMonthly&&mPoints.isEmpty){
      if(monthly!=null&&monthly['supported']==false){
        return Padding(
          padding:const EdgeInsets.only(top:10),
          child:Text('${monthly['reason']??'KAMIS 월별 시세 추이를 제공하지 않는 품목입니다.'}',style:const TextStyle(fontSize:11,color:Color(0xff52685c))),
        );
      }
      return const SizedBox.shrink();
    }
    final unitLabel='${monthly?['unitLabel']??'원/kg'}';
    final region='${monthly?['regionName']??''}';
    final cropLabel='${monthly?['cropLabel']??''}';
    final subTitle=mPoints.isEmpty
      ?'KAMIS 월평균 도매가격 불러오는 중…'
      :'KAMIS ${region.isEmpty?'도매':'$region 도매'}${cropLabel.isEmpty?'':' · $cropLabel'}';
    final minVal=mPoints.isEmpty?null:mPoints.map((e)=>e.value).reduce(math.min).round();
    final maxVal=mPoints.isEmpty?null:mPoints.map((e)=>e.value).reduce(math.max).round();
    return Container(
      key:const Key('market-monthly-trend-chart'),
      margin:const EdgeInsets.only(top:12),
      padding:const EdgeInsets.fromLTRB(14,14,14,12),
      decoration:BoxDecoration(color:const Color(0xffeef4fa),borderRadius:BorderRadius.circular(16)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text('월별 시세 추이${mPoints.isNotEmpty?' (최근 ${mPoints.length}개월)':''}',textAlign:TextAlign.center,style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold,color:Color(0xff1e3a4c))),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
          Flexible(child:Text(subTitle,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,color:Color(0xff1e6247)))),
          const SizedBox(width:8),
          Text('단위 : $unitLabel',style:const TextStyle(fontSize:11,color:Color(0xff52685c))),
        ]),
        if(_loadingMonthly)const Padding(padding:EdgeInsets.only(top:6),child:LinearProgressIndicator(minHeight:2)),
        if(mPoints.isNotEmpty)...[
          const SizedBox(height:8),
          SizedBox(height:170,child:CustomPaint(painter:_MarketTrendPainter(points:mPoints,lineColor:const Color(0xff1e6247),gridColor:const Color(0xffd6e2ec)))),
          if(minVal!=null&&maxVal!=null)Padding(
            padding:const EdgeInsets.only(top:6),
            child:Text('최근 ${mPoints.length}개월 평균 범위: 최저 ${marketMoney(minVal)}$unitLabel · 최고 ${marketMoney(maxVal)}$unitLabel',textAlign:TextAlign.center,style:const TextStyle(fontSize:11,color:Color(0xff52685c))),
          ),
        ],
      ]),
    );
  }
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
    final currentMarketName=_markets.firstWhere((m)=>m['code']==_marketCode,orElse:()=>{'name':'서울가락'})['name'];
    return ExpansionTile(
      key:const Key('market-catalogue-panel'),
      tilePadding:EdgeInsets.zero,
      title:Text('품목·도매시장 코드 전체 선택 (${_catalogue.length}개)',style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600)),
      subtitle:Text('[$currentMarketName] ${_customLabel.isEmpty?(marketProducts[_product]??_product):'$_customLabel ($_product)'}',style:const TextStyle(fontSize:12)),
      children:[
        const Align(alignment:Alignment.centerLeft,child:Text('공영도매시장 선택 (도매시장 코드 API)',style:TextStyle(fontSize:12,fontWeight:FontWeight.bold))),
        const SizedBox(height:4),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
          for(final m in _markets)Padding(padding:const EdgeInsets.only(right:6),child:ChoiceChip(
            key:ValueKey('market-whsal-${m['code']}'),
            label:Text('${m['name']}'),
            selected:_marketCode==m['code'],
            onSelected:_loading?null:(_){setState(()=>_marketCode=m['code']!);_load();},
          )),
        ])),
        const SizedBox(height:8),
        Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[
          Expanded(child:TextField(key:const Key('market-item-search'),controller:_searchController,onChanged:(v)=>setState(()=>_searchQuery=v),decoration:InputDecoration(labelText:'품목·품종·코드 검색',hintText:'예: 오이, 호박, 수박, 대파, 청양, 대저, 08:03',suffixIcon:_searchQuery.isEmpty?const Icon(Icons.search):IconButton(icon:const Icon(Icons.clear),onPressed:(){_searchController.clear();setState(()=>_searchQuery='');})))),
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
    final visibleChips=MarketPreferences.current.visibleProducts;
    return Scaffold(
      appBar:AppBar(title:const Text('농산물 경매 시세'),actions:[
        if(widget.client!=null)IconButton(key:const Key('market-open-setup'),tooltip:'시세 설정',onPressed:_loading||_loadingSummary?null:_openSettings,icon:const Icon(Icons.settings_outlined)),
        IconButton(key:const Key('market-refresh'),tooltip:'시세 다시 조회',onPressed:_loading||_loadingSummary?null:()=>_load(forceRefresh:true),icon:const Icon(Icons.refresh)),
      ]),
      body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Wrap(spacing:8,runSpacing:4,children:[
          for(final entry in marketProducts.entries)
            if(visibleChips.contains(entry.key)||_product==entry.key)
              ChoiceChip(key:Key('market-product-${entry.key}'),label:Text(entry.value),selected:_product==entry.key,onSelected:_loading?null:(_)=>_selectPreset(entry.key)),
          if(!marketProducts.containsKey(_product)&&_customLabel.isNotEmpty)ChoiceChip(key:const Key('market-product-custom'),label:Text(_customLabel),selected:true,onSelected:null),
        ]),
        _catalogueSection(),
        Row(children:[const Icon(Icons.calendar_month_outlined,size:18),const SizedBox(width:6),Expanded(child:Text('거래일 ${_sample?marketSampleDate:marketDay(_date)}')),TextButton(onPressed:_sample||_loading?null:_chooseDate,child:const Text('날짜 변경'))]),
        if(_loading)const LinearProgressIndicator(),
        if(_error.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(_error,key:const Key('market-error'),style:TextStyle(color:Theme.of(context).colorScheme.error))),
        if(_data!=null)...[
          DropdownButtonFormField<String>(key:ValueKey('market-filter-$_product-$_sample'),initialValue:_market,isExpanded:true,decoration:const InputDecoration(labelText:'시장 선택'),items:[const DropdownMenuItem(value:'',child:Text('조회된 시장 전체')),for(final name in markets)DropdownMenuItem(value:name,child:Text(name))],onChanged:(v)=>setState(()=>_market=v??'')),
          _dashboardSection(visible),
          Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text('${_data!['source']}\n${stamp==null?(_loadingSummary?'조회 시각 확인 중…':'조회 시각 미상'):'조회 시각 ${marketDay(stamp)} ${stamp.hour.toString().padLeft(2,'0')}:${stamp.minute.toString().padLeft(2,'0')}'}${_fromCache?' · 저장본 표시 (매일 08시 갱신)':(_data!['cached']==true?' · 서버 캐시':'')}',style:const TextStyle(fontSize:12))),
          if(_prefetching)Padding(padding:const EdgeInsets.only(bottom:6),child:Text('다른 품목 시세 미리 불러오는 중… ($_prefetchDone/$_prefetchTotal)',style:const TextStyle(fontSize:11,color:Color(0xff1e6247)))),
          if(!_loadingMoreQuotes&&_data!['truncated']==true)const Text('일부 거래만 조회했습니다. 전체 거래의 평균이나 전체 시장 가격으로 해석하지 마세요.'),
          Text('표시 ${visible.length}건 · ${_data!['priceBasis']=='unconfirmed'?'제공가격의 단가 기준 확인이 필요합니다.':'가격은 해당 거래의 규격당 낙찰가입니다.'}',style:const TextStyle(fontSize:12)),
          if(_loadingMoreQuotes)...[
            Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Text('개별 경락가 항목을 차례로 불러오는 중…${visible.isNotEmpty?' (${visible.length}건)':''}',style:const TextStyle(fontSize:12,color:Color(0xff2b7de9)))),
            const LinearProgressIndicator(minHeight:2),
          ],
          if(visible.isEmpty&&!_loadingMoreQuotes)Padding(padding:const EdgeInsets.all(20),child:Text(_data!['truncated']==true?'조회한 일부 거래에서 해당 품목을 찾지 못했습니다. 전체 거래에 자료가 없다는 의미는 아닙니다.':'해당 거래일의 자료가 없습니다. 휴장·수집 지연일 수 있으니 다른 날짜도 확인하세요.')),
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
      ]))),
    );
  }
}

class _MarketTrendPainter extends CustomPainter {
  const _MarketTrendPainter({
    required this.points,
    this.lineColor=const Color(0xff2b7de9),
    this.gridColor=const Color(0xffcde5da),
  });
  final List<({String label,double value})> points;
  final Color lineColor;
  final Color gridColor;
  @override
  void paint(Canvas canvas,Size size){
    if(points.isEmpty){return;}
    const leftPad=46.0,rightPad=12.0,topPad=10.0,bottomPad=24.0;
    final chartW=math.max(1.0,size.width-leftPad-rightPad);
    final chartH=math.max(1.0,size.height-topPad-bottomPad);
    final maxVal=points.map((p)=>p.value).reduce(math.max);
    final step=maxVal<=0?100.0:math.pow(10,math.max(1,(math.log(maxVal)/math.ln10).floor())).toDouble();
    final yMax=math.max(step*4,((maxVal/(step/2)).ceil()*(step/2)).toDouble());
    final gridPaint=Paint()..color=gridColor..strokeWidth=1;
    final bgPaint=Paint()..color=Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(leftPad,topPad,chartW,chartH),const Radius.circular(6)),bgPaint);
    for(var i=0;i<=4;i++){
      final ratio=i/4.0,y=topPad+chartH*(1-ratio);
      canvas.drawLine(Offset(leftPad,y),Offset(leftPad+chartW,y),gridPaint);
      final label=marketMoney((yMax*ratio).round());
      final tp=TextPainter(text:TextSpan(text:label,style:const TextStyle(fontSize:10,color:Color(0xff52685c))),textDirection:TextDirection.ltr)..layout();
      tp.paint(canvas,Offset(leftPad-tp.width-6,y-tp.height/2));
    }
    final coords=<Offset>[];
    final labelStep=points.length>8?2:1;
    for(var i=0;i<points.length;i++){
      final x=points.length==1?leftPad+chartW/2:leftPad+chartW*(i/(points.length-1));
      final y=topPad+chartH*(1-(yMax<=0?0:(points[i].value/yMax).clamp(0.0,1.0)));
      coords.add(Offset(x,y));
      if(i%labelStep==0||i==points.length-1){
        final tp=TextPainter(text:TextSpan(text:points[i].label,style:const TextStyle(fontSize:10,color:Color(0xff52685c))),textDirection:TextDirection.ltr)..layout();
        tp.paint(canvas,Offset(x-tp.width/2,topPad+chartH+6));
      }
    }
    if(coords.length>1){
      final path=Path()..moveTo(coords.first.dx,coords.first.dy);
      for(final pt in coords.skip(1)){path.lineTo(pt.dx,pt.dy);}
      canvas.drawPath(path,Paint()..color=lineColor..style=PaintingStyle.stroke..strokeWidth=2.2);
    }
    final fillPaint=Paint()..color=Colors.white..style=PaintingStyle.fill;
    final strokePaint=Paint()..color=lineColor..style=PaintingStyle.stroke..strokeWidth=2.2;
    for(final pt in coords){
      canvas.drawCircle(pt,4.5,fillPaint);
      canvas.drawCircle(pt,4.5,strokePaint);
    }
  }
  @override
  bool shouldRepaint(covariant _MarketTrendPainter oldDelegate)=>oldDelegate.points!=points||oldDelegate.lineColor!=lineColor||oldDelegate.gridColor!=gridColor;
}
