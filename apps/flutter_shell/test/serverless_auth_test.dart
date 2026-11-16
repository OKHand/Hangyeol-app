import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:crypto/crypto.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';
import 'package:hangyeol_platform/src/serverless/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
const endpoint='https://script.google.com/macros/s/api-fixture/exec';
class _Vault implements SessionVault {
  final values=<String,String>{};
  @override
  Future<String?> read(String key) async=>values[key];
  @override
  Future<void> write(String key,String value) async{values[key]=value;}
  @override
  Future<void> delete(String key) async{values.remove(key);}
}
class _UiClient extends AppsScriptPlatformClient {
  _UiClient():super(Uri.parse(endpoint));
  @override
  Future<GoogleDeviceLogin> startLogin() async => GoogleDeviceLogin(deviceCode:'ab'*32,verifier:'x'*43,userCode:'47',url:Uri.parse('https://script.google.com/macros/s/login/exec?device=${'ab'*32}'),expiresAt:DateTime.now().add(const Duration(minutes:5)));
  @override
  Future<Map<String,dynamic>?> poll(GoogleDeviceLogin login) async {token='cd'*32;return {'email':'viewer@example.com','role':'viewer','permissions':['erp.read']};}
  @override
  Future<Map<String,List<String>>> suggestions() async => {'customer':['실제 거래처'],'item':['토마토']};
  @override
  Future<void> logout() async {token=null;}
}
void main(){
  test('API URLs are restricted and storage is bound to the exact deployment',(){
    expect(()=>AppsScriptPlatformClient(Uri.parse('http://script.google.com/macros/s/abc/exec')),throwsA(isA<PlatformAuthFailure>()));
    expect(()=>AppsScriptPlatformClient(Uri.parse('https://attacker.example/exec')),throwsA(isA<PlatformAuthFailure>()));
    final a=AppsScriptPlatformClient(Uri.parse(endpoint)),b=AppsScriptPlatformClient(Uri.parse(endpoint.replaceFirst('api-fixture','different')));
    expect(a.storageKey,isNot(b.storageKey));a.close();b.close();
  });
  test('Google response redirect receives neither the session nor POST body',()async{
    final requests=<http.Request>[];
    final client=AppsScriptPlatformClient(Uri.parse(endpoint),client:MockClient((request)async{
      requests.add(request);
      if(request.url.host=='script.google.com'){return http.Response('',302,headers:{'location':'https://script.googleusercontent.com/macros/echo?key=public-response'});}
      return http.Response(jsonEncode({'ok':true,'result':{'user':{'email':'viewer@example.com'}}}),200);
    }))..token='ab'*32;
    await client.me();expect(requests.length,2);expect(requests.first.body,contains('ab'*32));expect(requests.last.method,'GET');expect(requests.last.body,isEmpty);expect(requests.last.headers['Authorization'],isNull);client.close();
  });
  test('untrusted redirects are blocked and anonymous requests contain no session',()async{
    var calls=0;
    final client=AppsScriptPlatformClient(Uri.parse(endpoint),client:MockClient((request)async{calls++;return http.Response('',302,headers:{'location':'https://attacker.example/steal'});}))..token='ab'*32;
    await expectLater(client.me(),throwsA(isA<PlatformAuthFailure>().having((e)=>e.code,'code','INVALID_REDIRECT')));expect(calls,1);client.close();
  });
  test('PKCE verifier stays out of browser URLs; poll uses the original private verifier',()async{
    String? challenge;
    final client=AppsScriptPlatformClient(Uri.parse(endpoint),client:MockClient((request)async{
      final body=jsonDecode(request.body) as Map;
      expect(body.containsKey('token'),isFalse);
      if(body['action']=='auth.start'){
        challenge=body['params']['challenge'] as String;
        return http.Response(jsonEncode({'ok':true,'result':{'deviceCode':'ab'*32,'userCode':'47','verificationUrl':'https://script.google.com/macros/s/google-login/exec?device=${'ab'*32}','expiresAt':DateTime.now().add(const Duration(minutes:5)).millisecondsSinceEpoch}}),200);
      }
      expect(sha256.convert(utf8.encode(body['params']['verifier'] as String)).toString(),challenge);
      return http.Response(jsonEncode({'ok':true,'result':{'status':'pending'}}),200);
    }));
    final login=await client.startLogin();expect(login.url.toString(),isNot(contains(login.verifier)));expect(login.url.queryParameters.keys,['device']);expect(await client.poll(login),isNull);client.close();
  });
  test('the real client adopts only an approved session and revokes it on logout',()async{
    final client=AppsScriptPlatformClient(Uri.parse(endpoint),client:MockClient((request)async{
      final body=jsonDecode(request.body) as Map;
      if(body['action']=='auth.poll') {return http.Response(jsonEncode({'ok':true,'result':{'status':'approved','token':'cd'*32,'user':{'email':'viewer@example.com','role':'viewer'}}}),200);}
      expect(body['action'],'auth.logout');expect(body['token'],'cd'*32);
      return http.Response(jsonEncode({'ok':true,'result':{'loggedOut':true}}),200);
    }));
    final user=await client.poll(GoogleDeviceLogin(deviceCode:'ab'*32,verifier:'x'*43,userCode:'47',url:Uri.parse(endpoint),expiresAt:DateTime.now().add(const Duration(minutes:5))));
    expect(user?['email'],'viewer@example.com');expect(client.token,'cd'*32);await client.logout();expect(client.token,isNull);client.close();
  });
  testWidgets('mobile browser failure exposes a copyable canonical login address without app secrets',(tester)async{
    final vault=_Vault(),client=_UiClient();String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,(call)async{if(call.method=='Clipboard.setData'){copied=(call.arguments as Map)['text'] as String;}return null;});
    addTearDown(()=>TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,null));
    await tester.pumpWidget(ServerlessApp(apiUrl:endpoint,client:client,vault:vault,launch:(_)async=>true));await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('google-login')));await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('로그인 화면이 열리지 않나요?'));await tester.tap(find.text('로그인 화면이 열리지 않나요?'));await tester.pumpAndSettle();
    final copy=find.byKey(const Key('copy-google-login-url'));await tester.ensureVisible(copy);await tester.tap(copy);await tester.pumpAndSettle();
    expect(copied,'https://script.google.com/macros/s/login/exec?device=${'ab'*32}');expect(copied,isNot(contains('x'*43)));expect(copied,isNot(contains('47')));expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());client.close();
  });
  testWidgets('unsupported isolated browser keeps recovery usable on initial launch and retry',(tester)async{
    final vault=_Vault(),client=_UiClient();var calls=0;
    await tester.pumpWidget(ServerlessApp(apiUrl:endpoint,client:client,vault:vault,launch:(_)async{calls++;throw PlatformAuthFailure('PRIVATE_BROWSER_REQUIRED','Chrome 업데이트 후 다시 시도해 주세요.');}));await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('google-login')));await tester.pumpAndSettle();
    expect(calls,1);expect(find.text('Chrome 업데이트 후 다시 시도해 주세요.'),findsOneWidget);
    await tester.ensureVisible(find.text('로그인 창 다시 열기'));await tester.tap(find.text('로그인 창 다시 열기'));await tester.pumpAndSettle();
    expect(calls,2);expect(find.text('Chrome 업데이트 후 다시 시도해 주세요.'),findsOneWidget);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());client.close();
  });
  testWidgets('Google approval shows the 2-digit match code, returns to the native ERP and persists a session without exposing staff controls to a viewer',(tester)async{
    final vault=_Vault();Uri? launched;
    final client=_UiClient();
    await tester.pumpWidget(ServerlessApp(apiUrl:endpoint,client:client,vault:vault,launch:(uri)async{launched=uri;return true;}));await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('google-login')));await tester.pumpAndSettle();expect(launched?.host,'accounts.google.com',reason:find.byType(Text).evaluate().map((e)=>(e.widget as Text).data??'').join(' | '));expect(find.byKey(const Key('login-match-code')),findsOneWidget);expect(find.text('47'),findsOneWidget);expect(find.text('브라우저에서 회사 Google 계정을 확인하고\n아래 2자리 번호를 눌러 승인해 주세요.'),findsOneWidget);
    await tester.tap(find.text('로그인 확인'));await tester.pumpAndSettle();expect(find.text('직원·권한'),findsNothing);expect(find.text('ERP 조회'),findsOneWidget);expect(vault.values[client.storageKey],'cd'*32);expect(find.text('빠른 체험'),findsNothing);
    await tester.tap(find.byTooltip('로그아웃'));await tester.pumpAndSettle();expect(vault.values,isEmpty);expect(find.byKey(const Key('google-login')),findsOneWidget);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());client.close();
  });
}
