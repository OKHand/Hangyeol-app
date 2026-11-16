import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/serverless/app_updates.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';

Map<String,dynamic> release(UpdatePlatform platform,{int build=21,String version='0.2.0'}){
  final tag=platform==UpdatePlatform.android?'platform-auth-photos-fixture':'windows-online-12345';
  final file=platform==UpdatePlatform.android?'hangyeol-online.apk':'hangyeol-online-windows.zip';
  return {'platform':platform.name,'version':version,'build':build,'bytes':55000000,'sha256':'a'*64,'commit':'b'*40,
    'downloadUrl':'https://github.com/OKHand/Hangyeol/releases/download/$tag/$file','releaseUrl':'https://github.com/OKHand/Hangyeol/releases/tag/$tag','publishedAt':'2026-11-10T00:00:00Z','notes':'설정에서 업데이트'};
}
class _Client extends AppsScriptPlatformClient {
  _Client():super(Uri.parse('https://script.google.com/macros/s/update-test/exec'));
  final requested=<Map<String,dynamic>>[];
  Map<String,dynamic>? value;
  PlatformAuthFailure? failure;
  @override
  Future<Map<String,dynamic>> call(String action,{Map<String,dynamic>? params,bool authenticated=true}) async {
    expect(action,'updates.check');expect(authenticated,isTrue);requested.add(params!);
    if(failure!=null){final error=failure!;failure=null;throw error;}
    return {'release':value};
  }
}
void main(){
  test('operating system detection and version comparison never offer a downgrade',(){
    addTearDown(()=>debugDefaultTargetPlatformOverride=null);
    for(final platform in [TargetPlatform.android,TargetPlatform.windows,TargetPlatform.iOS,TargetPlatform.linux]){
      debugDefaultTargetPlatformOverride=platform;
      expect(updatePlatform(),platform==TargetPlatform.android?UpdatePlatform.android:platform==TargetPlatform.windows?UpdatePlatform.windows:null);
    }
    final r=AppUpdateRelease.parse(release(UpdatePlatform.android),UpdatePlatform.android);
    expect(r.newerThan(const InstalledAppBuild(version:'0.2.0',build:20)),isTrue);
    expect(r.newerThan(const InstalledAppBuild(version:'0.2.0',build:21)),isFalse);
    expect(r.newerThan(const InstalledAppBuild(version:'0.3.0',build:20)),isFalse);
    expect(r.newerThan(const InstalledAppBuild(version:'0.2.0',build:22)),isFalse);
    expect(AppUpdateRelease.parse(release(UpdatePlatform.android,version:'0.3.0'),UpdatePlatform.android).newerThan(const InstalledAppBuild(version:'0.2.9',build:20)),isTrue);
  });
  test('untrusted hosts, another operating system and query tokens are rejected before opening a browser',(){
    final value=release(UpdatePlatform.android);
    for(final change in [
      {'downloadUrl':'https://evil.example/update.apk'},
      {'downloadUrl':'${value['downloadUrl']}?token=secret'},
      {'downloadUrl':(value['downloadUrl'] as String).replaceFirst('github.com','github.com.evil.example')},
      {'platform':'windows'}, {'sha256':'bad'}, {'build':0}, {'version':'latest'},
    ]){expect(()=>AppUpdateRelease.parse({...value,...change},UpdatePlatform.android),throwsA(isA<PlatformAuthFailure>()));}
  });
  for(final platform in UpdatePlatform.values){
    testWidgets('${platform.name} prefers the verified Drive installer and selects the company Google account',(tester) async {
      tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);
      addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);
      const id='verified-drive-installer-id';
      final client=_Client()..value={...release(platform),'driveFileId':id,'driveFolderId':'verified-platform-folder','driveDownloadUrl':'https://drive.google.com/uc?export=download&id=$id','drivePageUrl':'https://drive.google.com/file/d/$id/view'}..token='private-app-session';
      addTearDown(client.close);final opened=<Uri>[];
      await tester.pumpWidget(MaterialApp(home:AppUpdatePage(client:client,platform:platform,googleEmail:'company@example.com',installed:const InstalledAppBuild(build:20),onAuthError:(_)async{},launch:(uri)async{opened.add(uri);return true;})));await tester.pumpAndSettle();
      expect(find.text('Google Drive에서 다운로드합니다. 앱에서 사용하는 회사 Google 계정으로 로그인해 주세요.'),findsOneWidget);
      final button=find.byKey(const Key('update-download'));await tester.ensureVisible(button);await tester.tap(button);await tester.pumpAndSettle();
      expect(opened.single.host,'drive.google.com');expect(opened.single.queryParameters,{'export':'download','id':id,'authuser':'company@example.com'});expect(opened.single.toString(),isNot(contains('private-app-session')));
      final page=find.byKey(const Key('update-release-page'));await tester.ensureVisible(page);await tester.tap(page);await tester.pumpAndSettle();expect(opened.last.path,'/file/d/$id/view');
      expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('${platform.name} requests and opens only the matching installer without an app credential',(tester) async {
      tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);
      addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);
      final client=_Client()..value=release(platform)..token='secret-app-session';addTearDown(client.close);final opened=<Uri>[];
      await tester.pumpWidget(MaterialApp(home:AppUpdatePage(client:client,platform:platform,installed:const InstalledAppBuild(build:20),onAuthError:(_)async{},launch:(uri)async{opened.add(uri);return true;})));await tester.pumpAndSettle();
      expect(client.requested,[{'platform':platform.name}]);expect(find.text('새 버전이 있습니다.'),findsOneWidget);
      final download=find.byKey(const Key('update-download'));await tester.ensureVisible(download);await tester.tap(download);await tester.pumpAndSettle();
      expect(opened.single.toString(),client.value!['downloadUrl']);expect(opened.single.hasQuery,isFalse);expect(opened.single.toString(),isNot(contains('secret-app-session')));
      expect(opened.single.path.endsWith(platform==UpdatePlatform.android?'.apk':'.zip'),isTrue);
      final page=find.byKey(const Key('update-release-page'));await tester.ensureVisible(page);await tester.tap(page);await tester.pumpAndSettle();expect(opened.last.toString(),client.value!['releaseUrl']);
      expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  test('malformed or foreign Drive destinations never replace the checked installer',(){
    final value={...release(UpdatePlatform.android),'driveFileId':'verified-drive-installer-id','driveFolderId':'verified-platform-folder','driveDownloadUrl':'https://drive.google.com/uc?export=download&id=verified-drive-installer-id','drivePageUrl':'https://drive.google.com/file/d/verified-drive-installer-id/view'};
    for(final change in [{'driveDownloadUrl':'https://drive.google.com.evil.example/install'},{'driveDownloadUrl':'${value['driveDownloadUrl']}&token=secret'},{'drivePageUrl':'https://drive.google.com/file/d/different-installer-id/view'},{'driveFileId':'bad/id'}]){
      expect(()=>AppUpdateRelease.parse({...value,...change},UpdatePlatform.android),throwsA(isA<PlatformAuthFailure>()));
    }
  });
  testWidgets('retry recovers a failed check; absent, old and invalid releases have no download button',(tester) async {
    final client=_Client()..failure=PlatformAuthFailure('CONNECTION_FAILED','연결을 확인해 주세요.');addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(home:AppUpdatePage(client:client,platform:UpdatePlatform.android,installed:const InstalledAppBuild(build:20),onAuthError:(_)async{})));await tester.pumpAndSettle();
    expect(find.text('연결을 확인해 주세요.'),findsOneWidget);expect(find.byKey(const Key('update-download')),findsNothing);
    final check=find.byKey(const Key('update-check'));await tester.tap(check);await tester.pumpAndSettle();expect(find.text('이 기기에 등록된 업데이트가 아직 없습니다.'),findsOneWidget);
    client.value=release(UpdatePlatform.android,build:19);await tester.tap(check);await tester.pumpAndSettle();expect(find.byKey(const Key('update-download')),findsNothing);
    client.value=release(UpdatePlatform.windows);await tester.ensureVisible(check);await tester.tap(check);await tester.pumpAndSettle();expect(find.byKey(const Key('update-download')),findsNothing);
    expect(find.text('기기에 맞는 공식 업데이트 정보를 확인하지 못했습니다.'),findsOneWidget);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('current version may be downloaded again and browser failure leaves a usable recovery action',(tester) async {
    final client=_Client()..value=release(UpdatePlatform.android,build:20);addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(home:AppUpdatePage(client:client,platform:UpdatePlatform.android,installed:const InstalledAppBuild(build:20),onAuthError:(_)async{},launch:(_)async=>false)));await tester.pumpAndSettle();
    expect(find.text('현재 최신 버전입니다.'),findsOneWidget);final download=find.byKey(const Key('update-download'));await tester.ensureVisible(download);await tester.tap(download);await tester.pumpAndSettle();
    expect(find.text('다운로드 브라우저를 열지 못했습니다. 다시 시도하거나 다운로드 페이지를 열어 주세요.'),findsOneWidget);expect(find.byKey(const Key('update-release-page')),findsOneWidget);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('expired app login returns to the existing authentication handler',(tester) async {
    final client=_Client()..failure=PlatformAuthFailure('SESSION_EXPIRED','다시 로그인해 주세요.');addTearDown(client.close);Object? error;
    await tester.pumpWidget(MaterialApp(home:AppUpdatePage(client:client,platform:UpdatePlatform.windows,onAuthError:(value)async{error=value;})));await tester.pumpAndSettle();
    expect(error,isA<PlatformAuthFailure>());expect(find.byKey(const Key('update-download')),findsNothing);await tester.pumpWidget(const SizedBox.shrink());
  });
}
