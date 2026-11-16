import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';
import 'bridge.dart';
import 'config.dart';

class CompanyWebView extends StatefulWidget {
  const CompanyWebView({super.key,required this.config,required this.url,required this.bridge,required this.onLogout});
  final AppConfig config;
  final Uri url;
  final NativeBridge bridge;
  final VoidCallback onLogout;
  @override
  State<CompanyWebView> createState()=>_CompanyWebViewState();
}

class _CompanyWebViewState extends State<CompanyWebView> {
  late final BridgeGate _gate;
  WebViewController? _android;
  WebviewController? _windows;
  final List<StreamSubscription<dynamic>> _subscriptions=[];
  Uri? _current;
  String? _error;
  bool _loading=true;
  @override
  void initState(){super.initState();_gate=BridgeGate(widget.config);_initialize();}
  Future<void> _initialize() async {
    try {
      if(Platform.isWindows){
        final controller=WebviewController();_windows=controller;
        await controller.initialize();
        await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
        _subscriptions.add(controller.url.listen((value){
          _current=Uri.tryParse(value);
          // A same-document history.replaceState (ticket cleanup) must not
          // invalidate the bridge; it does not emit navigationCompleted.
          if(_current==null||!widget.config.trustedWeb(_current!)){
            _gate.invalidate();
            if(mounted){ setState(()=>_error='외부 화면은 앱 안에서 열 수 없습니다. 업무 화면으로 돌아가 주세요.'); }
          }
        }));
        _subscriptions.add(controller.webMessage.listen((value){_message(value is String?value:jsonEncode(value));}));
        _subscriptions.add(controller.loadingState.listen((state){
          if(state==LoadingState.loading){
            _gate.invalidate();
            if(mounted){setState(()=>_loading=true);}
          }
          if(state==LoadingState.navigationCompleted){_ready();}
        }));
        await controller.loadUrl(widget.url.toString());
      }else if(Platform.isAndroid){
        final controller=WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..addJavaScriptChannel('HangyeolNative',onMessageReceived:(message){_message(message.message);})
          ..setNavigationDelegate(NavigationDelegate(
            onNavigationRequest:(request)=>widget.config.trustedWeb(Uri.parse(request.url))?NavigationDecision.navigate:NavigationDecision.prevent,
            onPageStarted:(url){_gate.invalidate();_current=Uri.tryParse(url);if(mounted){ setState(()=>_loading=true); }},
            onPageFinished:(url){_current=Uri.tryParse(url);_ready();},
            onWebResourceError:(error){if(error.isForMainFrame==true&&mounted){ setState(()=>_error='업무 화면에 연결하지 못했습니다. 연결을 확인하고 다시 열어 주세요.'); }},
          ));
        _android=controller;
        await controller.loadRequest(widget.url);
      }else{
        throw UnsupportedError('현재 버전은 Windows와 Android에서 실행할 수 있습니다.');
      }
      if(mounted){ setState((){}); }
    }catch(error){if(mounted){ setState(()=>_error='화면을 준비하지 못했습니다. Windows에서는 WebView2 Runtime 설치 여부를 확인해 주세요.'); }}
  }
  Future<void> _evaluate(String script) async {
    if(_android!=null){await _android!.runJavaScript(script);}
    else if(_windows!=null){await _windows!.executeScript(script);}
  }
  Future<void> _ready() async {
    final current=_android!=null?Uri.tryParse(await _android!.currentUrl()??''):_current;
    if(current==null||!widget.config.trustedWeb(current)){ return; }
    _current=current;
    final nonce=_gate.activate(current);
    await _evaluate(bridgeScript(nonce,windows:Platform.isWindows));
    if(mounted){ setState((){_loading=false;_error=null;}); }
  }
  Future<void> _message(String raw) async {
    if(raw.length>128*1024){ return; }
    Map<String,dynamic> envelope;
    try{envelope=jsonDecode(raw) as Map<String,dynamic>;}catch(_){return;}
    final actual=_android!=null?Uri.tryParse(await _android!.currentUrl()??''):_current;
    if(!_gate.accepts(envelope,actual)){ return; }
    final request=envelope['request'];if(request is! Map<String,dynamic>){ return; }
    final nonce=envelope['nonce'] as String;
    Map<String,dynamic> response;
    try{
      final result=await widget.bridge.execute(request);
      response={'bridgeVersion':1,'requestId':request['requestId'],'result':result};
    }catch(error){
      final failure=error is BridgeFailure?error:BridgeFailure('REQUEST_FAILED',error.toString());
      response={'bridgeVersion':1,'requestId':request['requestId'],'error':{'code':failure.code,'message':failure.message}};
    }
    // Never send metadata into a page that navigated while a permission dialog was open.
    if(!_gate.isActive(nonce)||!mounted){ return; }
    await _evaluate('window.hangyeolBridgeReceive && window.hangyeolBridgeReceive(${jsonEncode(response)});');
    if(request['method']=='session.logout'&&mounted){ widget.onLogout(); }
  }
  @override
  void dispose(){_gate.invalidate();for(final s in _subscriptions){s.cancel();}_windows?.dispose();super.dispose();}
  @override
  Widget build(BuildContext context){
    if(_error!=null){ return Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.cloud_off_outlined,size:40),const SizedBox(height:16),Text(_error!,textAlign:TextAlign.center),const SizedBox(height:16),FilledButton(onPressed:widget.onLogout,child:const Text('연결 화면으로'))]))); }
    return Stack(children:[
      if(_android!=null)WebViewWidget(controller:_android!),
      if(_windows?.value.isInitialized==true)Webview(_windows!),
      if(_loading)const LinearProgressIndicator(minHeight:2),
    ]);
  }
}
