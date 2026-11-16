import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../demo/demo_erp.dart';
class PlatformAuthFailure implements Exception {
  PlatformAuthFailure(this.code,this.message);
  final String code,message;
  @override
  String toString()=>message;
}
class GoogleDeviceLogin {
  const GoogleDeviceLogin({required this.deviceCode,required this.verifier,required this.userCode,required this.url,required this.expiresAt});
  final String deviceCode,verifier,userCode;
  final Uri url;
  final DateTime expiresAt;
  Uri get browserUrl {
    final values=url.queryParametersAll;
    if(!AppsScriptPlatformClient.validApiUrl(url.replace(query:''))||values.length!=1||values['device']?.length!=1||values['device']?.single!=deviceCode||!RegExp(r'^[a-f0-9]{64}$').hasMatch(deviceCode)){
      throw PlatformAuthFailure('INVALID_LOGIN','Google 로그인 주소를 확인하지 못했습니다.');
    }
    // Select the Google account before Apps Script chooses a browser account
    // slot. The verifier, confirmation code and app session stay in the app.
    return Uri.https('accounts.google.com','/AccountChooser',{'continue':url.toString(),'service':'wise','hl':'ko'});
  }
}
class AppsScriptPlatformClient {
  AppsScriptPlatformClient(this.url,{http.Client? client}):_http=client??http.Client(){
    if(!validApiUrl(url)){throw PlatformAuthFailure('INVALID_URL','회사 Apps Script 연결 주소를 확인해 주세요.');}
  }
  final Uri url;
  final http.Client _http;
  String? _token;
  int _sessionGeneration=0, _cacheEpoch=0;
  final _reads=<String,({DateTime expires,Map<String,dynamic> value,int size})>{};
  final _pendingReads=<String,Future<Map<String,dynamic>>>{};
  String? get token=>_token;
  set token(String? value){if(value!=_token){_token=value;_sessionGeneration++;invalidateReadCache();}}
  void invalidateReadCache(){_reads.clear();_pendingReads.clear();_cacheEpoch++;}
  Map<String,dynamic> _copyRead(Map<String,dynamic> value)=>Map<String,dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  Future<Map<String,dynamic>> readCached(String action,{Map<String,dynamic>? params,Duration ttl=const Duration(seconds:20),bool force=false}) async {
    if(!const {'photos.list','erp.suggestions'}.contains(action)){throw ArgumentError('Only read-only catalog requests may be cached');}
    if(token==null){throw PlatformAuthFailure('AUTH_REQUIRED','Google 로그인이 필요합니다.');}
    if(force){invalidateReadCache();}
    final key=jsonEncode([action,params??{}]);
    final cached=_reads.remove(key);
    if(cached!=null&&DateTime.now().isBefore(cached.expires)){_reads[key]=cached;return _copyRead(cached.value);}
    final pending=_pendingReads[key];if(pending!=null){return _copyRead(await pending);}
    final session=_sessionGeneration,epoch=_cacheEpoch;
    late Future<Map<String,dynamic>> work;
    work=call(action,params:params).then((value){
      if(session!=_sessionGeneration){throw PlatformAuthFailure('SESSION_CHANGED','계정이 변경되었습니다. 다시 조회해 주세요.');}
      final size=jsonEncode(value).length;
      if(epoch==_cacheEpoch&&size<=2000000){
        _reads[key]=(expires:DateTime.now().add(ttl),value:_copyRead(value),size:size);
        while(_reads.length>24||_reads.values.fold<int>(0,(sum,e)=>sum+e.size)>2000000){_reads.remove(_reads.keys.first);}
      }
      return value;
    }).whenComplete((){if(identical(_pendingReads[key],work)){_pendingReads.remove(key);}});
    _pendingReads[key]=work;return _copyRead(await work);
  }
  static bool validApiUrl(Uri uri)=>uri.scheme=='https'&&uri.host=='script.google.com'&&RegExp(r'^/macros/s/[A-Za-z0-9_-]+/exec$').hasMatch(uri.path)&&uri.userInfo.isEmpty&&uri.query.isEmpty&&uri.fragment.isEmpty&&uri.port==443;
  String get storageKey=>'hangyeol.session.${sha256.convert(utf8.encode(url.toString()))}';
  Future<Map<String,dynamic>> call(String action,{Map<String,dynamic>? params,bool authenticated=true}) async {
    if(authenticated&&token==null){throw PlatformAuthFailure('AUTH_REQUIRED','Google 로그인이 필요합니다.');}
    final startingToken=token;
    final original=http.Request('POST',url)..followRedirects=false..headers['Content-Type']='application/json'..body=jsonEncode({'action':action,'params':params??{},if(authenticated)'token':token});
    final timeout=Duration(seconds:(action.startsWith('photos.')||action.startsWith('discord.'))?150:45);
    try {
      var response=await _http.send(original).timeout(timeout);
      for(var hop=0;response.statusCode>=300&&response.statusCode<400;hop++){
        final location=response.headers['location'];await response.stream.drain<void>();
        if(hop>=2||location==null){throw PlatformAuthFailure('INVALID_REDIRECT','조회 응답 주소를 확인하지 못했습니다.');}
        final redirect=original.url.resolve(location);
        if(redirect.scheme!='https'||redirect.host!='script.googleusercontent.com'||redirect.userInfo.isNotEmpty||redirect.port!=443){throw PlatformAuthFailure('INVALID_REDIRECT','허용되지 않은 응답 주소입니다.');}
        // Never forward a session, POST body or Authorization header on redirect.
        response=await _http.send(http.Request('GET',redirect)..followRedirects=false).timeout(timeout);
      }
      final chunks=BytesBuilder(copy:false);
      await for(final chunk in response.stream.timeout(timeout)){if(chunks.length+chunk.length>20*1024*1024){throw PlatformAuthFailure('RESULT_LIMIT','결과가 많습니다. 조회 조건을 좁혀 주세요.');}chunks.add(chunk);}
      if(response.statusCode!=200){throw PlatformAuthFailure('CONNECTION_FAILED','Apps Script 연결에 실패했습니다. 잠시 후 다시 시도해 주세요.');}
      Map<String,dynamic> value;
      try{value=jsonDecode(utf8.decode(chunks.takeBytes())) as Map<String,dynamic>;}catch(_){throw PlatformAuthFailure('OWNER_ACTIVATION_REQUIRED','관리자의 최초 Google 읽기 권한 승인이 필요합니다.');}
      if(value['ok']!=true){final error=value['error'] as Map<String,dynamic>?;throw PlatformAuthFailure(error?['code'] as String? ?? 'REQUEST_FAILED',error?['message'] as String? ?? '요청을 완료하지 못했습니다.');}
      if(authenticated&&token!=startingToken){throw PlatformAuthFailure('SESSION_CHANGED','계정이 변경되었습니다. 다시 조회해 주세요.');}
      if(const {'photos.upload','photos.update','photos.updateMany','photos.setup','photos.configure','photos.retry','photos.farmCreate','photos.visitCreate','photos.classify','discord.sync','staff'}.contains(action)){invalidateReadCache();}
      return Map<String,dynamic>.from(value['result'] as Map);
    } on PlatformAuthFailure catch(error) {if(const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(error.code)){invalidateReadCache();}rethrow;} catch(_){throw PlatformAuthFailure('CONNECTION_FAILED','인터넷 연결을 확인하고 다시 시도해 주세요.');}
  }
  Future<GoogleDeviceLogin> startLogin() async {
    final random=Random.secure(),verifier=base64Url.encode(List.generate(32,(_)=>random.nextInt(256))).replaceAll('=','');
    final result=await call('auth.start',authenticated:false,params:{'challenge':sha256.convert(utf8.encode(verifier)).toString()});
    final device=result['deviceCode'] as String,userCode=result['userCode'] as String,uri=Uri.parse(result['verificationUrl'] as String);
    final base=uri.replace(query:'');
    if(!RegExp(r'^[a-f0-9]{64}$').hasMatch(device)||!RegExp(r'^\d{2}$').hasMatch(userCode)||!validApiUrl(base)||uri.queryParameters.length!=1||uri.queryParameters['device']!=device){throw PlatformAuthFailure('INVALID_LOGIN','Google 로그인 주소를 확인하지 못했습니다.');}
    return GoogleDeviceLogin(deviceCode:device,verifier:verifier,userCode:userCode,url:uri,expiresAt:DateTime.fromMillisecondsSinceEpoch(result['expiresAt'] as int));
  }
  Future<Map<String,dynamic>?> poll(GoogleDeviceLogin login) async {
    final result=await call('auth.poll',authenticated:false,params:{'deviceCode':login.deviceCode,'verifier':login.verifier});
    if(result['status']=='pending'){return null;}
    final session=result['token'];if(session is! String||!RegExp(r'^[a-f0-9]{64}$').hasMatch(session)){throw PlatformAuthFailure('INVALID_LOGIN','로그인 응답을 확인하지 못했습니다.');}
    token=session;return Map<String,dynamic>.from(result['user'] as Map);
  }
  Future<Map<String,dynamic>> me() async=>Map<String,dynamic>.from((await call('auth.me'))['user'] as Map);
  Future<Map<String,List<String>>> suggestions() async {
    final data=await readCached('erp.suggestions',ttl:const Duration(minutes:2));return data.map((k,v)=>MapEntry(k,List<String>.from(v as List)));
  }
  Future<DemoReport> report(DemoQuery q) async {
    final result=await call('erp.query',params:{'mode':q.mode,'customers':demoTokens(q.customer),'divs':demoTokens(q.div),'items':demoTokens(q.item),'sales':demoTokens(q.sales),'origins':demoTokens(q.origin),'startDate':q.start==null?'':demoDay(q.start!),'endDate':q.end==null?'':demoDay(q.end!),'view':q.view,'groupBy':q.groupBy});
    if(result['success']!=true){return const DemoReport(['조회 결과'],[]);}
    final data=(result['data'] as List).map((r)=>List<String>.from(r as List)).toList();
    if(data.length<2){throw PlatformAuthFailure('INVALID_RESULT','조회 결과를 확인하지 못했습니다.');}
    final indices=data[1].indexed.where((c)=>c.$2.isNotEmpty&&c.$2!='System_UID').map((c)=>c.$1).toList();
    return DemoReport(indices.map((i)=>data[1][i]).toList(),data.skip(2).map((r)=>indices.map((i)=>i<r.length?r[i]:'').toList()).toList(),title:data.first.isEmpty?'':data.first.first);
  }
  Future<List<Map<String,dynamic>>> users() async { final result=await call('staff',params:{'operation':'list'});return List<Map<String,dynamic>>.from(result['users'] as List); }
  Future<void> saveUser({required String email,required String name,required String role,required bool active}) async {await call('staff',params:{'operation':'upsert','email':email,'name':name,'role':role,'active':active});}
  Future<void> logout() async {await call('auth.logout');token=null;}
  void close(){invalidateReadCache();_http.close();}
}
