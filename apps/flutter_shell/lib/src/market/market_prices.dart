import 'package:flutter/material.dart';
import '../serverless/client.dart';
import 'market_setup.dart';

const marketProducts={'chal-tomato':'찰토마토','date-cherry-tomato':'대추방울토마토'};
const marketSampleDate='2026-11-10';
// Invented demonstration trades, never presented as official/current prices.
Map<String,dynamic> marketSample(String product)=>{
  'product':product,'date':marketSampleDate,'sample':true,'source':'화면 체험용 가상 자료','fetchedAt':'','total':3,'truncated':false,
  'quotes':List.generate(3,(i){final cherry=product=='date-cherry-tomato',kg=cherry?3:5,price=(cherry?18000:14000)+i*2000;return <String,dynamic>{'id':'sample-$product-$i','product':product,'productName':marketProducts[product],'date':marketSampleDate,'market':i==2?'예시 도매시장 B':'예시 도매시장 A','grade':i==1?'상':'특','package':'${kg}kg 상자','price':price,'currency':'KRW','quantity':10+i*5,'weightKg':kg,'pricePerKg':price/kg};}),
};
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
  String _product='chal-tomato',_market='',_error='';
  late bool _sample;
  late DateTime _date;
  Map<String,dynamic>? _data;
  bool _loading=false;
  int _generation=0;
  @override
  void initState(){super.initState();_sample=widget.client==null;final kst=DateTime.now().toUtc().add(const Duration(hours:9));_date=DateTime(kst.year,kst.month,kst.day);_load();}
  Future<void> _load() async {
    final generation=++_generation;setState((){_loading=true;_error='';_data=null;_market='';});
    try{
      final result=_sample?marketSample(_product):await widget.client!.call('market.prices',params:{'product':_product,'date':marketDay(_date)});
      if(!mounted||generation!=_generation){return;}
      if(result['sample']!=_sample||result['product']!=_product||result['date']!=(_sample?marketSampleDate:marketDay(_date))||result['quotes'] is! List){throw PlatformAuthFailure('MARKET_RESPONSE_INVALID','조회 조건과 응답이 일치하지 않습니다.');}
      setState(()=>_data=result);
    }catch(e){
      if(!mounted||generation!=_generation){return;}
      if(e is PlatformAuthFailure&&const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(e.code)){await widget.onAuthError?.call(e);}
      if(mounted&&generation==_generation){setState(()=>_error=e is PlatformAuthFailure?e.message:'시세를 불러오지 못했습니다. 다시 확인해 주세요.');}
    }finally{if(mounted&&generation==_generation){setState(()=>_loading=false);}}
  }
  Future<void> _chooseDate() async {
    final kst=DateTime.now().toUtc().add(const Duration(hours:9));
    final value=await showDatePicker(context:context,initialDate:_date,firstDate:DateTime(2010),lastDate:DateTime(kst.year,kst.month,kst.day));
    if(value!=null&&mounted){setState(()=>_date=value);await _load();}
  }
  @override
  void dispose(){_generation++;super.dispose();}
  @override
  Widget build(BuildContext context){
    final rows=List<Map<String,dynamic>>.from(_data?['quotes'] as List? ?? []),markets=rows.map((r)=>r['market'] as String).toSet().toList()..sort();
    final visible=rows.where((r)=>_market.isEmpty||r['market']==_market).toList();
    final stamp=DateTime.tryParse(_data?['fetchedAt'] as String? ?? '')?.toLocal();
    return Scaffold(appBar:AppBar(title:const Text('토마토 경매 시세'),actions:[if(widget.canManage&&widget.client!=null)IconButton(key:const Key('market-open-setup'),tooltip:'시세 품목 연결',onPressed:_loading?null:() async {final result=await Navigator.of(context).push<bool>(MaterialPageRoute(builder:(_)=>MarketSetupPage(client:widget.client!,onAuthError:widget.onAuthError)));if(result==true&&mounted){await _load();}},icon:const Icon(Icons.settings_outlined)),IconButton(key:const Key('market-refresh'),tooltip:'시세 다시 조회',onPressed:_loading?null:_load,icon:const Icon(Icons.refresh))]),body:SafeArea(child:ListView(padding:const EdgeInsets.all(12),children:[
      if(widget.client!=null)Wrap(spacing:8,children:[ChoiceChip(key:const Key('market-live'),label:const Text('실제 시세'),selected:!_sample,onSelected:_loading?null:(_){setState(()=>_sample=false);_load();}),ChoiceChip(key:const Key('market-sample'),label:const Text('예시 자료 보기'),selected:_sample,onSelected:_loading?null:(_){setState(()=>_sample=true);_load();})]),
      if(_sample)Container(key:const Key('market-sample-banner'),margin:const EdgeInsets.symmetric(vertical:8),padding:const EdgeInsets.all(12),color:Theme.of(context).colorScheme.surfaceContainerHighest,child:const Text('체험용 가상 가격입니다. 실제 시장 시세가 아닙니다.',style:TextStyle(fontWeight:FontWeight.bold))),
      Wrap(spacing:8,children:[for(final entry in marketProducts.entries)ChoiceChip(key:Key('market-product-${entry.key}'),label:Text(entry.value),selected:_product==entry.key,onSelected:_loading?null:(_){setState(()=>_product=entry.key);_load();})]),
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
