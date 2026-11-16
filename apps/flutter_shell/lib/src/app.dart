import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'bridge.dart';
import 'company_webview.dart';
import 'config.dart';
import 'upload_queue.dart';

class HangyeolApp extends StatelessWidget {
  const HangyeolApp({super.key});
  @override
  Widget build(BuildContext context)=>MaterialApp(
    title:'한결씨드',debugShowCheckedModeBanner:false,
    theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff1e6247),brightness:Brightness.light),scaffoldBackgroundColor:const Color(0xfff7f9f7),useMaterial3:true),
    home:const PlatformHome(),
  );
}
class PlatformHome extends StatefulWidget {
  const PlatformHome({super.key});
  @override
  State<PlatformHome> createState()=>_PlatformHomeState();
}
class _PlatformHomeState extends State<PlatformHome> with WidgetsBindingObserver {
  final _config=AppConfig.environment();
  late final NativeApi _api;
  late final UploadQueue _queue;
  late final NativeBridge _bridge;
  Uri? _url;
  String? _error;
  bool _busy=false;
  Timer? _timer;
  @override
  void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_api=NativeApi(_config.apiUrl);_queue=UploadQueue(_api);_bridge=NativeBridge(_queue);_initialize();}
  Future<void> _initialize()async{
    try{await _queue.initialize();}catch(_){if(mounted){ setState(()=>_error='기기에 보관된 업로드 목록을 읽지 못했습니다. 원본 파일을 확인해 주세요.'); }}
    _timer=Timer.periodic(const Duration(seconds:30),(_){if(_api.userId!=null){ _queue.retry(); }});
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed){ _queue.retry(); }}
  Future<void> _connect()async{
    if(!_config.valid||!_config.development){ return; }
    setState((){_busy=true;_error=null;});
    try{
      final ticket=await _api.developmentSession();
      if(mounted){ setState(()=>_url=_config.webUrl.replace(fragment:'session_ticket=${Uri.encodeComponent(ticket)}')); }
      _queue.retry();
    }catch(error){if(mounted){ setState(()=>_error=error is ApiFailure?error.message:'서버에 연결하지 못했습니다. 개발 서버가 실행 중인지 확인해 주세요.'); }}
    finally{if(mounted){ setState(()=>_busy=false); }}
  }
  void _disconnect(){_api.clearSession();_queue.clearUnqueuedAssets();setState(()=>_url=null);}
  @override
  void dispose(){WidgetsBinding.instance.removeObserver(this);_timer?.cancel();_api.close();super.dispose();}
  @override
  Widget build(BuildContext context){
    if(_url!=null){ return Scaffold(appBar:AppBar(toolbarHeight:40,title:const Text('한결씨드',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold)),actions:[IconButton(tooltip:'연결 화면',onPressed:_disconnect,icon:const Icon(Icons.close,size:20))]),body:CompanyWebView(config:_config,url:_url!,bridge:_bridge,onLogout:_disconnect)); }
    return Scaffold(body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Icon(Icons.eco_outlined,size:52,color:Color(0xff1e6247)),const SizedBox(height:18),
      const Text('한결씨드',textAlign:TextAlign.center,style:TextStyle(fontSize:30,fontWeight:FontWeight.w700)),
      const SizedBox(height:6),const Text('현장의 기록을 하나로',textAlign:TextAlign.center,style:TextStyle(color:Color(0xff52685c))),
      const SizedBox(height:28),
      if(!_config.valid)const Text('업무 웹과 서버 주소를 설정한 빌드가 필요합니다. 개발 시험은 DEVELOPMENT 설정을 사용해 주세요.',textAlign:TextAlign.center),
      if(_config.valid&&_config.development)...[
        const Text('개발 시험 환경',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:8),
        const Text('시험 계정으로 사진 등록과 기기 기능을 확인합니다.',textAlign:TextAlign.center),const SizedBox(height:18),
        FilledButton.icon(onPressed:_busy?null:_connect,icon:_busy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.arrow_forward),label:const Text('개발 환경 연결')),
      ],
      if(_config.valid&&!_config.development)const Text('회사 Google 로그인 연결 설정이 필요합니다. 이 초기 빌드에서는 개발 환경으로 기기 기능을 시험할 수 있습니다.',textAlign:TextAlign.center),
      if(_error!=null)...[const SizedBox(height:18),Text(_error!,textAlign:TextAlign.center,style:TextStyle(color:Theme.of(context).colorScheme.error))],
    ])))));
  }
}
