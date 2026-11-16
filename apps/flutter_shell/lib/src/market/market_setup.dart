import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../serverless/client.dart';

class MarketSetupPage extends StatefulWidget {
  const MarketSetupPage({super.key,required this.client,this.onAuthError});
  final AppsScriptPlatformClient client;
  final Future<void> Function(Object)? onAuthError;
  @override
  State<MarketSetupPage> createState()=>_MarketSetupPageState();
}
class _MarketSetupPageState extends State<MarketSetupPage> {
  final _market=TextEditingController(text:'110001');
  final _items=<String,Map<String,dynamic>>{};
  final _choices=<String,String>{};
  final _operation=const Uuid().v4();
  Map<String,dynamic>? _settings,_pendingSave;
  bool _busy=false,_allowHttp=false,_started=false;
  int? _next=1;
  int _scanned=0;
  String _error='';
  static const products={'chal-tomato':'찰토마토','date-cherry-tomato':'대추방울토마토'};
  @override
  void initState(){super.initState();_load();}
  Future<void> _work(Future<void> Function() run) async {
    if(_busy){return;}setState((){_busy=true;_error='';});
    try{await run();}catch(e){if(e is PlatformAuthFailure&&const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(e.code)){await widget.onAuthError?.call(e);}if(mounted){setState(()=>_error=e is PlatformAuthFailure?e.message:'연결 설정을 확인하지 못했습니다.');}}
    finally{if(mounted){setState(()=>_busy=false);}}
  }
  Future<void> _load()=>_work(() async {final data=await widget.client.call('market.settings');if(mounted){setState((){_settings=data;_market.text=data['marketCode'] as String? ?? '110001';_allowHttp=data['allowPlainHttp']==true;});}});
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
  Widget build(BuildContext context)=>PopScope(canPop:!_busy,child:Scaffold(appBar:AppBar(title:const Text('시세 품목 연결'),actions:[TextButton(key:const Key('market-setup-save'),onPressed:_busy||_choices.length!=2||_settings==null?null:_save,child:const Text('연결 저장'))]),body:SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[
    if(_busy)const LinearProgressIndicator(),if(_error.isNotEmpty)Text(_error,style:TextStyle(color:Theme.of(context).colorScheme.error)),
    Text(_settings?['keyConfigured']==true?'서버에 API 이용키가 등록돼 있습니다.':'서버 이용키 등록을 확인해 주세요.'),
    const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('공식 품목 코드 API에서 사용 중인 품종을 찾아 연결합니다. 시세를 볼 시장은 아래에서 지정합니다. 거래가 없는 날짜에도 품목 코드를 확인할 수 있습니다.')),
    const SizedBox(height:10),TextField(key:const Key('market-setup-code'),controller:_market,enabled:!_busy&&!_started,keyboardType:TextInputType.number,maxLength:6,decoration:const InputDecoration(labelText:'도매시장 코드',helperText:'110001 = 서울가락 (제공된 샘플 기준)')),
    CheckboxListTile(key:const Key('market-setup-http'),contentPadding:EdgeInsets.zero,title:const Text('제공처의 HTTP 연결 방식 확인'),subtitle:const Text('명세의 HTTP 주소로 서버의 API 이용키를 전송합니다. 암호화되지 않은 연결임을 확인하고 선택하세요.'),value:_allowHttp,onChanged:_busy||_started?null:(v)=>setState(()=>_allowHttp=v==true)),
    FilledButton.icon(key:const Key('market-discover'),onPressed:_busy||!_allowHttp||_settings?['keyConfigured']!=true||_next==null||_pendingSave!=null?null:_discover,icon:const Icon(Icons.search),label:Text(_started?'다음 코드에서 품목 찾기':'공식 코드에서 품목 찾기')),
    Text('조회한 코드 $_scanned건 · 찾은 토마토 분류 ${_items.length}개',style:const TextStyle(fontSize:12)),
    const Text('한 번 누를 때 최대 1,000개 코드를 확인합니다. 품목이 아직 보이지 않으면 다음 코드를 확인하세요. 품목 코드 API의 추가 이용 승인이 필요할 수 있습니다.',style:TextStyle(fontSize:12)),
    if(_started)TextButton(onPressed:_busy||_pendingSave!=null?null:()=>setState((){_started=false;_next=1;_scanned=0;_items.clear();_choices.clear();}),child:const Text('시장·분류 다시 선택')),
    for(final product in products.entries)...[
      Padding(padding:const EdgeInsets.only(top:16,bottom:8),child:Text('${product.value}에 연결할 실제 분류',style:const TextStyle(fontWeight:FontWeight.bold))),
      if(!_items.values.any((i)=>(i['eligible'] as List).contains(product.key)))const Text('현재 자료에서 정확히 해당하는 명칭을 찾지 못했습니다.',style:TextStyle(fontSize:12)),
      for(final item in _items.values.where((i)=>(i['eligible'] as List).contains(product.key)))ListTile(key:ValueKey('market-choice-${product.key}-${item['id']}'),dense:true,selected:_choices[product.key]==item['id'],leading:Icon(_choices[product.key]==item['id']?Icons.radio_button_checked:Icons.radio_button_off),title:Text('${item['category']} / ${item['variety']}'),subtitle:Text(item['id'] as String),onTap:_busy||_pendingSave!=null?null:()=>setState(()=>_choices[product.key]=item['id'] as String)),
    ],
    if(_items.isNotEmpty)ExpansionTile(title:const Text('조회된 다른 토마토 분류'),children:[for(final item in _items.values.where((i)=>(i['eligible'] as List).isEmpty))ListTile(dense:true,title:Text('${item['category']} / ${item['variety']}'),subtitle:Text(item['id'] as String))]),
    const Padding(padding:EdgeInsets.only(top:16),child:Text('일반 토마토를 찰토마토로 자동 확정하지 않습니다. 제공처가 두 품목을 구분하지 않는 경우 임의로 연결할 수 없습니다.')),
  ]))));
}
