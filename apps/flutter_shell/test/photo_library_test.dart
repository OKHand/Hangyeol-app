import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';
import 'package:hangyeol_platform/src/serverless/photo_library.dart';
import 'package:hangyeol_platform/src/serverless/photo_repository.dart';
import 'package:hangyeol_platform/src/serverless/photos.dart';

class LibraryClient extends AppsScriptPlatformClient {
  LibraryClient():super(Uri.parse('https://script.google.com/macros/s/library-test/exec'));
  final writes=<Map<String,dynamic>>[];
  final photo=<String,dynamic>{'id':'11111111-1111-4111-8111-111111111111','metadataVersion':'v1','farm':'','crop':'','variety':'','region':'','note':'','date':'','source':'discord','email':'','notification':'not_applicable','createdAt':'2026-11-10T00:00:00Z','reviewStatus':'needs_review'};
  bool failOnce=true;
  @override
  Future<Map<String,dynamic>> call(String action,{Map<String,dynamic>? params,bool authenticated=true}) async {
    if(action=='photos.library'){return {'farms':[{'id':'farm-1','name':'나상 가명A종묘','region':'담양'}],'visits':[],'nextOffset':null};}
    if(action=='discord.jobs'){return {'settings':{'configured':false,'version':'0'},'jobs':[],'counts':{}};}
    if(action=='photos.list'){final rows=params?['review']=='needs_review'&&photo['reviewStatus']=='ready'?<Map<String,dynamic>>[]:[photo];return {'photos':rows,'total':rows.length,'config':{'ready':true,'discordConfigured':true},'nextOffset':null};}
    if(action=='photos.classify'){
      writes.add(Map<String,dynamic>.from(params!));
      photo.addAll({'farm':'나상 가명A종묘','farmId':'farm-1','crop':'토마토','reviewStatus':'ready','metadataVersion':'v2'});
      if(failOnce){failOnce=false;throw PlatformAuthFailure('CONNECTION_FAILED','응답이 끊겼습니다. 다시 저장해 주세요.');}
      return {'photos':[photo]};
    }
    throw StateError('Unexpected action $action');
  }
}
class LibraryRepository extends PhotoRepository {
  LibraryRepository(super.client);
  @override
  Future<Uint8List?> thumbnail(Map<String,dynamic> photo) async=>null;
  @override
  Future<Map<String,dynamic>> list({String query='',String field='all',String groupBy='all',int offset=0,bool force=false,bool exact=false})=>client.call('photos.list');
}
void phone(WidgetTester tester){tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);}
void main(){
  testWidgets('inbox classification saves above the keyboard and repeats a lost acknowledgement without changing the operation',(tester) async {
    phone(tester);final client=LibraryClient()..token='a'*64,repository=LibraryRepository(client);
    addTearDown(client.close);addTearDown(repository.dispose);
    await tester.pumpWidget(MaterialApp(home:PhotoLibraryPage(client:client,repository:repository,onAuthError:(_)async{},openPhoto:(_)async{})));
    await tester.pumpAndSettle();expect(find.text('정보 보완 필요'),findsOneWidget);expect(find.text('농가 미입력 · 작물 미입력'),findsOneWidget);
    await tester.tap(find.byKey(ValueKey('library-select-${client.photo['id']}')));await tester.pumpAndSettle();await tester.tap(find.byKey(const Key('library-classify')));await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-farm')));await tester.pumpAndSettle();await tester.tap(find.text('나상 가명A종묘 · 담양').last);await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('library-crop')),'토마토');
    tester.view.viewInsets=const FakeViewPadding(bottom:300);addTearDown(tester.view.resetViewInsets);await tester.pumpAndSettle();
    final save=find.byKey(const Key('library-classify-save'));expect(tester.getRect(save).bottom,lessThan(100));await tester.tap(save);await tester.pumpAndSettle();
    expect(find.text('응답이 끊겼습니다. 다시 저장해 주세요.'),findsOneWidget);await tester.tap(save);await tester.pumpAndSettle();
    expect(client.writes,hasLength(2));expect(client.writes[0],client.writes[1]);expect(client.writes.first['changes'],{'farmId':'farm-1','crop':'토마토'});
    expect(client.photo['date'],'');expect(find.text('조건에 맞는 사진이 없습니다.'),findsOneWidget);expect(tester.takeException(),isNull);
  });
  testWidgets('members do not receive catalogue controls and imported photos have no outbound retry button',(tester) async {
    phone(tester);final client=LibraryClient()..token='a'*64,repository=LibraryRepository(client);
    addTearDown(client.close);addTearDown(repository.dispose);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:OnlinePhotosPage(client:client,email:'member@example.com',canCreate:true,owner:false,onAuthError:(_)async{},repository:repository))));
    await tester.pumpAndSettle();expect(find.byKey(const Key('photo-open-library')),findsNothing);expect(find.byTooltip('Discord 전송 재시도'),findsNothing);expect(find.text('Discord에서 가져옴'),findsOneWidget);expect(tester.takeException(),isNull);
  });
  testWidgets('Discord intake remains disabled until an admin connects a channel',(tester) async {
    phone(tester);final client=LibraryClient()..token='a'*64,repository=LibraryRepository(client);
    addTearDown(client.close);addTearDown(repository.dispose);
    await tester.pumpWidget(MaterialApp(home:PhotoLibraryPage(client:client,repository:repository,onAuthError:(_)async{},openPhoto:(_)async{})));
    await tester.pumpAndSettle();await tester.tap(find.text('Discord 수집'));await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('discord-import-sync'))).onPressed,isNull);expect(find.text('Discord 수집 미연결'),findsOneWidget);expect(tester.takeException(),isNull);
  });
}
