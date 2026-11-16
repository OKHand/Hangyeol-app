import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:file_selector/file_selector.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'upload_queue.dart';

class BridgeFailure implements Exception {
  const BridgeFailure(this.code,this.message);
  final String code,message;
}

/// A per-document capability is injected only into the trusted top frame.
/// The raw native channel is present in frames, but it cannot be used without
/// this unguessable capability. Navigating invalidates outstanding requests.
class BridgeGate {
  BridgeGate(this.config);
  final AppConfig config;
  String? _nonce;
  Uri? _current;
  String activate(Uri page) {
    if(!config.trustedWeb(page)){ throw const BridgeFailure('FORBIDDEN','허용되지 않은 화면입니다.'); }
    _current=page;
    _nonce=base64UrlEncode(List<int>.generate(32,(_)=>Random.secure().nextInt(256)));
    return _nonce!;
  }
  void invalidate(){_nonce=null;_current=null;}
  bool accepts(Map<String,dynamic> envelope,Uri? current) => _nonce!=null&&current!=null&&config.trustedWeb(current)&&_current!=null&&AppConfig.sameOrigin(_current!,current)&&envelope['nonce']==_nonce;
  bool isActive(String nonce) => nonce==_nonce;
}

class NativeBridge {
  NativeBridge(this.queue);
  final UploadQueue queue;
  Future<Map<String,dynamic>> execute(Map<String,dynamic> request) async {
    final id=request['requestId'];
    if(request['bridgeVersion']!=1||id is! String||id.isEmpty||id.length>128){ throw const BridgeFailure('INVALID_REQUEST','지원하지 않는 앱 요청입니다.'); }
    final params=(request['params'] as Map?)?.cast<String,dynamic>()??{};
    switch(request['method']){
      case 'capabilities.get':return {'bridgeVersion':1,'camera':Platform.isAndroid,'photos':true,'location':Platform.isAndroid,'nativeUploads':queue.api.userId!=null,'multiplePhotos':false};
      case 'camera.capture':
      case 'photos.pick':
        final isCamera=request['method']=='camera.capture';
        if(isCamera&&!Platform.isAndroid){ throw const BridgeFailure('UNSUPPORTED','이 기기에서는 파일에서 사진을 선택해 주세요.'); }
        final owner=queue.api.userId;
        if(owner==null){ throw const BridgeFailure('AUTH_REQUIRED','앱에서 먼저 로그인해 주세요.'); }
        final List<LocalAsset> assets=[];
        if(Platform.isAndroid){
          final picker=ImagePicker();
          final lost=await picker.retrieveLostData();
          if(lost.exception!=null){ throw BridgeFailure('CAMERA_RECOVERY_FAILED',lost.exception!.message??'이전 촬영을 복구하지 못했습니다.'); }
          if(lost.files?.isNotEmpty==true){
            for(final file in lost.files!){assets.add(await queue.importFile(file.path,name:file.name,ownerId:owner));}
            return {'assets':assets.map((e)=>e.publicView()).toList(),'recovered':true};
          }
          if(isCamera){final file=await picker.pickImage(source:ImageSource.camera);if(file!=null){ assets.add(await queue.importFile(file.path,name:file.name,newlyCaptured:true,ownerId:owner)); }}
          else {
            final file=await picker.pickImage(source:ImageSource.gallery);
            if(file!=null){assets.add(await queue.importFile(file.path,name:file.name,ownerId:owner));}
          }
        }else{
          final file=await openFile(acceptedTypeGroups:[const XTypeGroup(label:'사진',extensions:['jpg','jpeg','png','webp'])]);
          if(file!=null){assets.add(await queue.importFile(file.path,name:file.name,ownerId:owner));}
        }
        if(assets.isEmpty){ throw const BridgeFailure('CANCELLED','사진 선택을 취소했습니다.'); }
        return {'assets':assets.map((e)=>e.publicView()).toList()};
      case 'location.request':
        if(!Platform.isAndroid){ throw const BridgeFailure('UNSUPPORTED','이 기기에서는 주소를 직접 입력해 주세요.'); }
        if(!await Geolocator.isLocationServiceEnabled()){ throw const BridgeFailure('LOCATION_DISABLED','기기의 위치 기능을 켜 주세요.'); }
        var permission=await Geolocator.checkPermission();
        if(permission==LocationPermission.denied){ permission=await Geolocator.requestPermission(); }
        if(permission==LocationPermission.denied||permission==LocationPermission.deniedForever){ throw const BridgeFailure('PERMISSION_DENIED','위치 권한이 없어 주소를 자동 입력하지 않았습니다.'); }
        final position=await Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,timeLimit:Duration(seconds:20)));
        return {'latitude':position.latitude,'longitude':position.longitude,'accuracy':position.accuracy,'source':'device'};
      case 'uploads.enqueue':
        final handle=params['handle'];final metadata=params['metadata'];
        if(handle is! String||metadata is! Map){ throw const BridgeFailure('INVALID_REQUEST','사진 정보가 올바르지 않습니다.'); }
        final entry=await queue.enqueue(handle,metadata.cast<String,dynamic>());
        // Enqueue must return promptly even in the field without connectivity.
        queue.retry();
        return entry.publicView();
      case 'uploads.status':return {'items':queue.status()};
      case 'uploads.retry':await queue.retry(id:params['id'] as String?);return {'items':queue.status()};
      case 'external.open':
        final url=Uri.tryParse(params['url'] as String? ?? '');
        if(url==null||url.scheme!='https'||url.host.isEmpty||url.userInfo.isNotEmpty){ throw const BridgeFailure('FORBIDDEN','HTTPS 주소만 외부 브라우저에서 열 수 있습니다.'); }
        if(!await launchUrl(url,mode:LaunchMode.externalApplication)){ throw const BridgeFailure('OPEN_FAILED','외부 브라우저를 열 수 없습니다.'); }
        return {'opened':true};
      case 'session.logout':
        try {await queue.api.request('/v1/auth/logout',method:'POST',body:{});}finally{queue.api.clearSession();queue.clearUnqueuedAssets();}
        return {'loggedOut':true};
      default:throw const BridgeFailure('UNSUPPORTED','현재 앱이 지원하지 않는 기능입니다.');
    }
  }
}

String bridgeScript(String nonce,{required bool windows}) {
  final send=windows?'window.chrome.webview.postMessage(JSON.stringify(envelope));':'HangyeolNative.postMessage(JSON.stringify(envelope));';
  return '''(()=>{if(window!==window.top)return;const nonce=${jsonEncode(nonce)};
Object.defineProperty(window,'HangyeolBridge',{configurable:true,value:Object.freeze({postMessage(text){const request=JSON.parse(text);const envelope={nonce,request};$send}})});
window.dispatchEvent(new Event('hangyeol-bridge-ready'));})();''';
}
