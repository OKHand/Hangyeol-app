import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'client.dart';
const _authBrowser=MethodChannel('hangyeol/isolated_auth_browser');
bool trustedLoginBrowserUrl(Uri uri){
  if(uri.scheme!='https'||uri.host!='accounts.google.com'||uri.port!=443||uri.userInfo.isNotEmpty||uri.fragment.isNotEmpty||uri.path!='/AccountChooser'){return false;}
  final fields=uri.queryParametersAll;
  if(fields.length!=3||fields['continue']?.length!=1||fields['service']?.length!=1||fields['service']?.single!='wise'||fields['hl']?.length!=1||fields['hl']?.single!='ko'){return false;}
  final target=Uri.tryParse(uri.queryParameters['continue']??'');
  return target!=null&&AppsScriptPlatformClient.validApiUrl(target.replace(query:''))&&target.queryParametersAll.length==1&&target.queryParametersAll['device']?.length==1&&RegExp(r'^[a-f0-9]{64}$').hasMatch(target.queryParameters['device']??'');
}
Future<bool> openIsolatedLoginBrowser(Uri uri) async {
  if(!trustedLoginBrowserUrl(uri)){throw PlatformAuthFailure('INVALID_LOGIN','로그인 주소를 확인하지 못했습니다.');}
  final android=defaultTargetPlatform==TargetPlatform.android;
  if(android||defaultTargetPlatform==TargetPlatform.windows){
    try{if(await _authBrowser.invokeMethod<bool>('open',uri.toString())==true){return true;}}on PlatformException catch(_){/* Show an explicit recovery instead of reusing conflicting cookies. */}on MissingPluginException catch(_){}
    throw PlatformAuthFailure('PRIVATE_BROWSER_REQUIRED',android?'독립 로그인 창을 지원하는 최신 Chrome이 필요합니다. Chrome 업데이트 후 다시 시도하거나, 아래 도움말에서 주소를 복사해 비밀 모드에서 여세요.':'독립 로그인 창을 열지 못했습니다. 아래 도움말의 주소를 Edge InPrivate 또는 Chrome 시크릿 창에서 열어 주세요.');
  }
  return launchUrl(uri,mode:LaunchMode.externalApplication);
}
