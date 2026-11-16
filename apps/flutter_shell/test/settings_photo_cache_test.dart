import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:hangyeol_platform/src/serverless/app.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';
import 'package:hangyeol_platform/src/serverless/photos.dart';

class _Vault implements SessionVault {
  @override
  Future<String?> read(String key)async=>'a'*64;
  @override
  Future<void> write(String key,String value)async{}
  @override
  Future<void> delete(String key)async{}
}
class _Client extends AppsScriptPlatformClient {
  _Client():super(Uri.parse('https://script.google.com/macros/s/cache-settings-test/exec'));
  final calls=<String>[];
  @override
  Future<Map<String,dynamic>> me() async=>{'email':'viewer@example.com','role':'viewer','permissions':['erp.read','photos.read']};
  @override
  Future<Map<String,List<String>>> suggestions() async=>{};
  @override
  Future<Map<String,dynamic>> call(String action,{Map<String,dynamic>? params,bool authenticated=true}) async {calls.add(action);throw StateError('No server access should be needed to clear local cache');}
}
class _Repository extends PhotoRepository {
  _Repository(super.client);
  int files=3,cleared=0;
  @override
  Future<PhotoCacheStats> cacheStats()async=>PhotoCacheStats(files,files*1024);
  @override
  Future<void> clearCache()async{files=0;cleared++;}
}
class _Paths extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async=>Directory.systemTemp.path;
}
void main(){
  testWidgets('Settings clears the same account repository without opening Photos or requesting server data',(tester)async{
    tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);
    addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);
    final client=_Client()..token='a'*64;addTearDown(client.close);_Repository? repository;var created=0;
    final oldPaths=PathProviderPlatform.instance;PathProviderPlatform.instance=_Paths();addTearDown(()=>PathProviderPlatform.instance=oldPaths);
    await tester.pumpWidget(ServerlessApp(apiUrl:client.url.toString(),client:client,vault:_Vault(),photoRepositoryFactory:(api,email){expect(email,'viewer@example.com');created++;return repository=_Repository(api);}));await tester.pumpAndSettle();
    expect(created,0);await tester.tap(find.descendant(of:find.byType(NavigationBar),matching:find.text('설정')));await tester.pumpAndSettle();
    final settings=find.byKey(const Key('settings-photo-cache'));await tester.ensureVisible(settings);await tester.tap(settings);await tester.pumpAndSettle();expect(created,1);
    final scope=sha256.convert(utf8.encode('${client.storageKey}:viewer@example.com'));
    expect(repository!.cacheDirectory!.path,'${Directory.systemTemp.path}/company-photos/$scope/cache');
    final clear=find.byKey(const Key('photo-cache-clear'));await tester.tap(clear);await tester.pumpAndSettle();
    expect(find.text('사진 캐시를 삭제했습니다.'),findsOneWidget);
    expect(repository!.files,0);expect(repository!.cleared,1);expect(client.calls,isEmpty);
    await tester.tap(find.text('닫기'));await tester.pumpAndSettle();await tester.tap(settings);await tester.pumpAndSettle();expect(created,1);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
  });
}
