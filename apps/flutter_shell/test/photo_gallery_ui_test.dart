import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';
import 'package:hangyeol_platform/src/serverless/photos.dart';
import 'gallery_test_data.dart';

class GalleryRepository extends PhotoRepository {
  GalleryRepository(super.client);
  final rows=<Map<String,dynamic>>[];
  final queries=<Map<String,dynamic>>[];
  @override
  Future<Map<String,dynamic>> list({String query='',String field='all',String groupBy='all',int offset=0,bool force=false,bool exact=false}) async {
    queries.add({'query':query,'field':field,'groupBy':groupBy,'exact':exact});
    final matching=rows.where((p)=>photoMatches(p,field,query,exact:exact)).toList();
    if(groupBy!='all'){matching.sort((a,b)=>(a[groupBy] as String).compareTo(b[groupBy] as String));}
    final groups=<String,int>{};
    if(groupBy!='all'){for(final photo in matching){final group=photo[groupBy] as String;groups[group]=(groups[group]??0)+1;}}
    return {'photos':matching,'nextOffset':null,'total':matching.length,'groups':groups,
      'config':{'ready':true,'discordConfigured':true},
      'suggestions':{'farm':['나상 가명A종묘','하상 농가 B'],'crop':['토마토'],'variety':['루비'],'date':['2026-11-01'],'region':['전남 담양','강원 춘천']}};
  }
  @override
  Future<Uint8List?> thumbnail(Map<String,dynamic> photo) async=>galleryPng();
  @override
  Future<Uint8List> original(Map<String,dynamic> photo) async=>galleryPng();
  @override
  Future<void> rememberThumbnail(Map<String,dynamic> photo,Uint8List bytes) async {}
}
class GalleryDraftStore extends PhotoDraftStore {
  GalleryDraftStore():super(Directory('/unused-gallery-test'));
  List<Map<String,dynamic>> rows=[];
  @override
  Future<List<Map<String,dynamic>>> load() async=>rows;
  @override
  Future<void> save(List<Map<String,dynamic>> drafts) async {rows=List.from(drafts);}
  @override
  Future<List<Map<String,dynamic>>> addBatch(List<File> originals,Map<String,dynamic> meta,List<Map<String,dynamic>> drafts,
    {bool camera=false,void Function(int,int)? onProgress}) async {
    final created=List.generate(originals.length,(i)=><String,dynamic>{...meta,'requestId':galleryPhoto(i)['id'],
      'batchId':'11111111-1111-4111-8111-111111111111','batchSize':originals.length,'batchIndex':i,'status':'pending'});
    await save([...drafts,...created]);return created;
  }
  @override
  Future<Uint8List> originalBytes(String id) async=>galleryPng();
  @override
  Future<Uint8List?> previewBytes(String id) async=>galleryPng();
  @override
  Future<List<Map<String,dynamic>>> removeStored(List<Map<String,dynamic>> drafts) async {
    final pending=drafts.where((d)=>d['status']!='stored').toList();await save(pending);return pending;
  }
}
class GalleryUploadClient extends AppsScriptPlatformClient {
  GalleryUploadClient(this.upload):super(Uri.parse('https://script.google.com/macros/s/gallery-upload/exec'));
  final Future<Map<String,dynamic>> Function(Map<String,dynamic>) upload;
  @override
  Future<Map<String,dynamic>> call(String action,{Map<String,dynamic>? params,bool authenticated=true}) {
    if(action!='photos.upload'){throw StateError('Unexpected gallery request: $action');}
    return upload(params??{});
  }
}
void largeScreen(WidgetTester tester){
  tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(1000,1600);
  addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);
}
void main(){
  testWidgets('first screen displays thumbnails and local suggestions dismiss outside; grouped and field searches are explicit',(tester) async {
    largeScreen(tester);
    final client=AppsScriptPlatformClient(Uri.parse('https://script.google.com/macros/s/gallery-ui/exec'))..token='a'*64;
    final repository=GalleryRepository(client)..rows.addAll(List.generate(3,galleryPhoto));
    addTearDown(client.close);addTearDown(repository.dispose);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:OnlinePhotosPage(client:client,email:'viewer@example.com',canCreate:false,owner:false,onAuthError:(_)async{},repository:repository))));
    await tester.pumpAndSettle();expect(find.byKey(const Key('photo-thumbnail-image')),findsWidgets);
    final search=find.byKey(const Key('photo-search-input'));
    await tester.enterText(search,'가명A');await tester.pumpAndSettle();expect(find.text('나상 가명A종묘'),findsOneWidget);
    await tester.tap(find.text('작황 사진'),kind:PointerDeviceKind.touch);await tester.pumpAndSettle();
    expect(find.text('나상 가명A종묘'),findsNothing);
    await tester.tap(search);await tester.pumpAndSettle();await tester.tap(find.text('나상 가명A종묘'));await tester.pumpAndSettle();
    expect(repository.queries.last['query'],'나상 가명A종묘');
    await tester.tap(find.byKey(const ValueKey('photo-group-all')));await tester.pumpAndSettle();
    await tester.tap(find.text('농가별').last);await tester.pumpAndSettle();
    expect(repository.queries.last['groupBy'],'farm');expect(find.text('나상 가명A종묘 · 2장'),findsOneWidget);
    await tester.enterText(search,'2026-11');await tester.testTextInput.receiveAction(TextInputAction.search);await tester.pumpAndSettle();
    expect(repository.queries.last['query'],'2026-11');
    await tester.tap(find.byKey(const ValueKey('photo-field-all')));await tester.pumpAndSettle();
    await tester.tap(find.text('촬영일').last);await tester.pumpAndSettle();
    expect(repository.queries.last['field'],'date');expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('eleven-photo selection uses one common form and resumes failures with the same IDs',(tester) async {
    largeScreen(tester);final uploads=<Map<String,dynamic>>[];var failOnce=true;
    late GalleryRepository repository;
    final client=GalleryUploadClient((params)async{
      uploads.add(Map<String,dynamic>.from(params));
      if(params['batchIndex']==1&&failOnce){failOnce=false;throw PlatformAuthFailure('CONNECTION_FAILED','연결 확인 후 재시도');}
      final photo={...galleryPhoto(params['batchIndex'] as int),...params,'id':params['requestId'],'state':'stored'};
      repository.rows.add(photo);return {'photo':photo};
    })..token='a'*64;
    repository=GalleryRepository(client);final store=GalleryDraftStore();
    addTearDown(client.close);addTearDown(repository.dispose);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:OnlinePhotosPage(client:client,email:'member@example.com',canCreate:true,owner:false,
      onAuthError:(_)async{},repository:repository,draftStore:store,pickPhotos:(_)async=>List.generate(11,(i)=>File('/source-$i.png'))))));
    await tester.pumpAndSettle();await tester.tap(find.byKey(const Key('photo-select-many')));await tester.pumpAndSettle();
    expect(find.text('사진 11장 공통 정보'),findsOneWidget);
    await tester.enterText(find.byKey(const Key('photo-form-farm')),'나상 가명A종묘');
    await tester.enterText(find.byKey(const Key('photo-form-crop')),'토마토');
    final save=find.byKey(const Key('photo-form-save'));await tester.ensureVisible(save);await tester.tap(save);await tester.pumpAndSettle();
    expect(uploads,hasLength(2),reason:store.rows.toString());expect(store.rows,hasLength(10));
    final failedId=uploads.last['requestId'];
    final retry=find.text('모두 재시도');await tester.ensureVisible(retry);await tester.tap(retry);await tester.pumpAndSettle();
    expect(uploads,hasLength(12),reason:store.rows.toString());expect(uploads[2]['requestId'],failedId);
    expect(uploads.map((p)=>p['requestId']).toSet(),hasLength(11));expect(uploads.every((p)=>p['batchSize']==11&&p['farm']=='나상 가명A종묘'&&p['thumbnail']!=null),isTrue);
    expect(store.rows,isEmpty);expect(repository.rows,hasLength(11));expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('compact list leaves cache controls in Settings and detail fields open exact collections with back navigation',(tester) async {
    tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);
    addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);
    final client=AppsScriptPlatformClient(Uri.parse('https://script.google.com/macros/s/photo-links/exec'))..token='a'*64;
    final first={...galleryPhoto(0),'note':''};
    final repository=GalleryRepository(client)..rows.addAll([first,{...galleryPhoto(1),'farm':'나상 가명A종묘 본점','variety':'루비킹','note':''}]);
    addTearDown(client.close);addTearDown(repository.dispose);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:OnlinePhotosPage(client:client,email:'viewer@example.com',canCreate:false,owner:false,onAuthError:(_)async{},repository:repository))));
    await tester.pumpAndSettle();
    final card=find.byKey(ValueKey('photo-${first['id']}'));
    expect(tester.getSize(card).height,lessThan(100));
    expect(tester.widget<Text>(find.byKey(ValueKey('photo-notification-${first['id']}'))).style!.fontSize,11);
    expect(find.byKey(const Key('photo-settings')),findsNothing);expect(find.byKey(const Key('photo-cache-clear')),findsNothing);
    await tester.ensureVisible(card);await tester.tap(card);await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo-browse-farm')));await tester.pumpAndSettle();
    expect(repository.queries.last,containsPair('field','farm'));expect(repository.queries.last,containsPair('query','나상 가명A종묘'));expect(repository.queries.last,containsPair('exact',true));
    expect(find.byKey(const Key('photo-exact-filter')),findsOneWidget);expect(find.byKey(ValueKey('photo-${galleryPhoto(1)['id']}')),findsNothing);
    await tester.pageBack();await tester.pumpAndSettle();expect(find.text('사진 상세'),findsOneWidget);
    for(final field in ['crop','variety','date','region']){
      final target=find.byKey(Key('photo-browse-$field'));await tester.ensureVisible(target);await tester.tap(target);await tester.pumpAndSettle();
      expect(repository.queries.last,containsPair('field',field));expect(repository.queries.last,containsPair('query',first[field]));expect(repository.queries.last,containsPair('exact',true));
      await tester.pageBack();await tester.pumpAndSettle();
    }
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
  });

}
