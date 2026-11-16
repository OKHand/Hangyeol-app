import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/serverless/app.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';
import 'package:hangyeol_platform/src/serverless/company_connections.dart';

class _Vault implements SessionVault {
  @override
  Future<String?> read(String key) async=>'a'*64;
  @override
  Future<void> write(String key,String value) async{}
  @override
  Future<void> delete(String key) async{}
}
class _Client extends AppsScriptPlatformClient {
  _Client(this.role):super(Uri.parse('https://script.google.com/macros/s/settings-test/exec'));
  final String role;
  final calls=<String>[],saved=<Map<String,dynamic>>[];
  bool fail=false,ready=true;
  Map<String,dynamic> config={'ready':true,'folderUrl':'https://drive.google.com/drive/folders/original-folder','discordConfigured':true,'settingsVersion':'v1'};
  @override
  Future<Map<String,dynamic>> me() async=>{'email':'$role@example.com','role':role,'permissions':['erp.read',if(['owner','admin'].contains(role))'staff.manage']};
  @override
  Future<Map<String,List<String>>> suggestions() async=>{};
  @override
  Future<Map<String,dynamic>> call(String action,{Map<String,dynamic>? params,bool authenticated=true}) async {
    calls.add(action);
    if(action=='photos.settings'){return {...config,'ready':ready};}
    if(action=='photos.setup'){ready=true;return config;}
    if(action=='photos.configure'){
      saved.add(Map.from(params!));
      if(fail){fail=false;throw PlatformAuthFailure('PHOTO_SETTINGS_CONFLICT','다른 곳에서 변경되었습니다. 최신 연결 설정을 확인해 주세요.');}
      config={...config,'settingsVersion':'v2',if(params.containsKey('folderUrl'))'folderUrl':params['folderUrl'],if(params.containsKey('webhook'))'discordConfigured':(params['webhook'] as String).isNotEmpty};return config;
    }
    throw StateError('Unexpected request: $action');
  }
}
void main(){
  for(final role in ['viewer','member','admin','owner']){
    testWidgets('$role sees Settings, only administrators see company and staff controls',(tester) async {
      final client=_Client(role);addTearDown(client.close);
      await tester.pumpWidget(ServerlessApp(apiUrl:client.url.toString(),client:client,vault:_Vault()));await tester.pumpAndSettle();
      await tester.tap(find.descendant(of:find.byType(NavigationBar),matching:find.text('설정')));await tester.pumpAndSettle();
      final admin=['owner','admin'].contains(role);
      expect(find.byKey(const Key('settings-app-update')),findsOneWidget);expect(find.byKey(const Key('settings-photo-cache')),findsOneWidget);
      expect(find.byKey(const Key('settings-company-connections')),admin?findsOneWidget:findsNothing);
      expect(find.byKey(const Key('settings-staff')),admin?findsOneWidget:findsNothing);expect(client.calls,isEmpty);
      if(admin){await tester.tap(find.byKey(const Key('settings-company-connections')));await tester.pumpAndSettle();expect(client.calls,['photos.settings']);}
      expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('top save remains above keyboard, edits survive a conflict and only selected settings are sent',(tester) async {
    tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);
    addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetViewInsets);
    final client=_Client('admin')..token='a'*64;addTearDown(client.close);var changes=0;
    await tester.pumpWidget(MaterialApp(home:CompanyConnectionsPage(client:client,owner:false,onAuthError:(_)async{},onChanged:()=>changes++)));await tester.pumpAndSettle();
    final save=find.byKey(const Key('company-settings-save'));
    expect(tester.widget<TextButton>(save).onPressed,isNull);
    await tester.tap(find.byKey(const Key('company-change-folder')));await tester.pumpAndSettle();
    final folder=find.byKey(const Key('company-folder-url'));await tester.enterText(folder,'https://drive.google.com/drive/folders/destination-folder');
    tester.view.viewInsets=const FakeViewPadding(bottom:320);await tester.pumpAndSettle();
    expect(tester.getRect(save).bottom,lessThan(100));client.fail=true;await tester.tap(save);await tester.pumpAndSettle();
    expect(changes,0);expect(tester.widget<TextFormField>(folder).controller!.text,contains('destination-folder'));
    expect(client.saved.single,{'expectedVersion':'v1','folderUrl':'https://drive.google.com/drive/folders/destination-folder'});
    tester.view.resetViewInsets();FocusManager.instance.primaryFocus?.unfocus();await tester.pumpAndSettle();
    final refresh=find.byKey(const Key('company-settings-refresh'));await tester.ensureVisible(refresh);await tester.tap(refresh);await tester.pumpAndSettle();
    // Refresh replaces the destination from the authoritative snapshot.
    await tester.ensureVisible(folder);await tester.enterText(folder,'https://drive.google.com/drive/folders/destination-folder');
    await tester.tap(save);await tester.pumpAndSettle();expect(changes,1);expect(find.byKey(const Key('company-folder-url')),findsNothing);
    final discord=find.byKey(const Key('company-change-discord'));await tester.ensureVisible(discord);await tester.tap(discord);await tester.pumpAndSettle();
    final webhook=find.byKey(const Key('company-discord-url'));await tester.ensureVisible(webhook);
    expect(tester.widget<TextFormField>(webhook).controller!.text,isEmpty);expect(tester.widget<TextField>(find.descendant(of:webhook,matching:find.byType(TextField))).obscureText,isTrue);
    await tester.tap(save);await tester.pumpAndSettle();expect(client.saved.last,{'expectedVersion':'v2','webhook':''});expect(changes,2);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('first storage initialization stays restricted to the owner',(tester) async {
    final client=_Client('admin')..ready=false;addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(home:CompanyConnectionsPage(client:client,owner:false,onAuthError:(_)async{},onChanged:(){})));await tester.pumpAndSettle();
    expect(find.byKey(const Key('company-settings-initialize')),findsNothing);expect(find.byKey(const Key('company-change-folder')),findsNothing);expect(client.calls,['photos.settings']);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
