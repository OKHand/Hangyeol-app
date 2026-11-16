import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';
import 'package:hangyeol_platform/src/serverless/photos.dart';
import 'gallery_test_data.dart';
import 'photo_gallery_ui_test.dart' show GalleryRepository;

class BulkClient extends AppsScriptPlatformClient {
  BulkClient():super(Uri.parse('https://script.google.com/macros/s/bulk-edit-test/exec'));
  final updates=<Map<String,dynamic>>[];
  late GalleryRepository repository;
  bool failOnce=true;
  @override
  Future<Map<String,dynamic>> call(String action,{Map<String,dynamic>? params,bool authenticated=true}) async {
    expect(action,'photos.updateMany');updates.add(params!);
    final ids=(params['targets'] as List).map((t)=>t['id']).toSet();
    final changes=Map<String,dynamic>.from(params['changes'] as Map);
    final changed=<Map<String,dynamic>>[];
    for(var i=0;i<repository.rows.length;i++){
      if(ids.contains(repository.rows[i]['id'])){
        repository.rows[i]={...repository.rows[i],...changes,'metadataVersion':'v2'};changed.add(repository.rows[i]);
      }
    }
    if(failOnce){failOnce=false;throw PlatformAuthFailure('CONNECTION_FAILED','응답을 확인하지 못했습니다. 다시 저장해 주세요.');}
    return {'photos':changed};
  }
}
void phone(WidgetTester tester){
  tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);
  addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);
}
void main(){
  testWidgets('members select only their photos and retry the same patch without changing unchecked metadata',(tester) async {
    phone(tester);final client=BulkClient()..token='a'*64;
    final repository=GalleryRepository(client)..rows.addAll([
      {...galleryPhoto(0),'metadataVersion':'v1'},
      {...galleryPhoto(1),'metadataVersion':'v1','email':'other@example.com'},
      {...galleryPhoto(2),'metadataVersion':'v1','note':'다른 메모'},
    ]);client.repository=repository;addTearDown(client.close);addTearDown(repository.dispose);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:OnlinePhotosPage(client:client,email:'member@example.com',canCreate:true,owner:false,onAuthError:(_)async{},repository:repository))));
    await tester.pumpAndSettle();await tester.tap(find.byKey(const Key('photo-start-selection')));await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo-select-loaded')));await tester.pumpAndSettle();
    expect(find.text('선택 2/100장'),findsOneWidget);
    final other=find.byKey(ValueKey('photo-check-${galleryPhoto(1)['id']}'));await tester.ensureVisible(other);
    expect(tester.widget<Checkbox>(other).onChanged,isNull);
    expect(tester.widget<TextField>(find.byKey(const Key('photo-search-input'))).readOnly,isTrue);
    final edit=find.byKey(const Key('photo-edit-selected'));expect(tester.getRect(edit).top,lessThan(150));await tester.tap(edit);await tester.pumpAndSettle();
    expect(find.text('사진 2장 정보 일괄 수정'),findsOneWidget);
    await tester.tap(find.byKey(const Key('bulk-enable-variety')));await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bulk-field-variety')),'새 품종');
    tester.view.viewInsets=const FakeViewPadding(bottom:320);addTearDown(tester.view.resetViewInsets);await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('bulk-save'))).bottom,lessThan(100));
    final save=find.byKey(const Key('bulk-save'));await tester.ensureVisible(save);await tester.tap(save);await tester.pumpAndSettle();
    expect(find.text('응답을 확인하지 못했습니다. 다시 저장해 주세요.'),findsOneWidget);
    expect(tester.widget<TextFormField>(find.byKey(const Key('bulk-field-variety'))).controller!.text,'새 품종');
    await tester.ensureVisible(save);await tester.tap(save);await tester.pumpAndSettle();
    expect(client.updates,hasLength(2));expect(client.updates[0]['operationId'],client.updates[1]['operationId']);
    expect(client.updates.last['changes'],{'variety':'새 품종'});
    expect((client.updates.last['targets'] as List).map((t)=>t['expectedVersion']),['v1','v1']);
    expect(repository.rows[0]['farm'],'나상 가명A종묘');expect(repository.rows[2]['note'],'다른 메모');
    expect(repository.rows[1]['variety'],'루비');expect(find.byKey(const Key('photo-selected-count')),findsNothing);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('loaded-list selection stops at one hundred and cancellation restores normal browsing',(tester) async {
    phone(tester);final client=BulkClient()..token='a'*64;
    final repository=GalleryRepository(client)..rows.addAll(List.generate(105,(i)=>{...galleryPhoto(i),'metadataVersion':'v1'}));client.repository=repository;
    addTearDown(client.close);addTearDown(repository.dispose);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:OnlinePhotosPage(client:client,email:'owner@example.com',canCreate:true,owner:true,onAuthError:(_)async{},repository:repository))));
    await tester.pumpAndSettle();await tester.tap(find.byKey(const Key('photo-start-selection')));await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo-select-loaded')));await tester.pumpAndSettle();expect(find.text('선택 100/100장'),findsOneWidget);
    await tester.tap(find.byTooltip('선택 취소'));await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-selected-count')),findsNothing);expect(tester.widget<TextField>(find.byKey(const Key('photo-search-input'))).readOnly,isFalse);
    expect(client.updates,isEmpty);expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
  });
}
