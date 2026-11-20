import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';
import 'package:hangyeol_platform/src/serverless/photos.dart';
import 'gallery_test_data.dart';
class DetailClient extends AppsScriptPlatformClient {
  DetailClient():super(Uri.parse('https://script.google.com/macros/s/detail-test/exec'));
  final updates=<Map<String,dynamic>>[];
  bool fail=true;
  @override
  Future<Map<String,dynamic>> call(String action,{Map<String,dynamic>? params,bool authenticated=true}) async {
    expect(action,'photos.update');updates.add(Map.from(params!));
    if(fail){fail=false;throw PlatformAuthFailure('CONNECTION_FAILED','연결 확인 후 다시 저장해 주세요.');}
    return {'photo':{...galleryPhoto(0),...params,'metadataVersion':'v2'}};
  }
}
class DetailRepository extends PhotoRepository {
  DetailRepository(super.client);
  @override
  Future<Uint8List> original(Map<String,dynamic> photo) async=>galleryPng();
}
void main(){
  testWidgets('full page shows a large image and metadata, toggles image only and retains edits after a failed save',(tester) async {
    tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);
    addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);
    final client=DetailClient()..token='a'*64;final repo=DetailRepository(client);
    addTearDown(client.close);addTearDown(repo.dispose);
    await tester.pumpWidget(MaterialApp(home:PhotoDetailPage(photo:{...galleryPhoto(0),'metadataVersion':'v1'},repository:repo,client:client,canEdit:true,onAuthError:(_)async{})));
    await tester.pumpAndSettle();
    final image=find.byKey(const Key('photo-detail-image'));expect(tester.getSize(image).width,390);expect(tester.getSize(image).height,greaterThan(400));
    expect(find.text('나상 가명A종묘'),findsOneWidget);expect(find.text('루비'),findsOneWidget);
    await tester.tap(find.byKey(const Key('photo-detail-fullscreen')));await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-detail-info')),findsNothing);expect(tester.getSize(image).height,greaterThan(700));
    await tester.tap(find.byKey(const Key('photo-detail-fullscreen')));await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo-detail-edit')));await tester.pumpAndSettle();
    final farm=find.byKey(const Key('photo-form-farm'));
    expect(tester.widget<TextFormField>(farm).controller!.text,'나상 가명A종묘');
    await tester.enterText(farm,'수정 농가');
    tester.view.viewInsets=const FakeViewPadding(bottom:320);addTearDown(tester.view.resetViewInsets);await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('photo-form-save'))).bottom,lessThan(100));
    final save=find.byKey(const Key('photo-form-save'));await tester.ensureVisible(save);await tester.tap(save);await tester.pumpAndSettle();
    expect(find.text('연결 확인 후 다시 저장해 주세요.'),findsOneWidget);
    expect(tester.widget<TextFormField>(farm).controller!.text,'수정 농가');
    await tester.ensureVisible(save);await tester.tap(save);await tester.pumpAndSettle();
    expect(find.text('사진 상세'),findsOneWidget);expect(find.text('수정 농가'),findsOneWidget);
    expect(client.updates,hasLength(2));expect(client.updates.last['expectedVersion'],'v1');expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('read only viewer sees information without an edit action',(tester) async {
    final client=DetailClient()..token='a'*64;final repo=DetailRepository(client);addTearDown(client.close);addTearDown(repo.dispose);
    await tester.pumpWidget(MaterialApp(home:PhotoDetailPage(photo:galleryPhoto(0),repository:repo,client:client,canEdit:false,onAuthError:(_)async{})));
    await tester.pumpAndSettle();expect(find.byKey(const Key('photo-detail-info')),findsOneWidget);
    expect(find.byKey(const Key('photo-detail-edit')),findsNothing);expect(client.updates,isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('download icon button sits to the left of fullscreen button and saves original photo to device',(tester) async {
    tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);
    addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);
    final client=DetailClient()..token='a'*64;final repo=DetailRepository(client);
    addTearDown(client.close);addTearDown(repo.dispose);
    String? savedName;
    String? savedMime;
    Uint8List? savedBytes;
    await tester.pumpWidget(MaterialApp(
      home:PhotoDetailPage(
        photo:galleryPhoto(0),
        repository:repo,
        client:client,
        canEdit:true,
        onAuthError:(_)async{},
        onSaveToDevice:(fileName,mime,bytes)async{
          savedName=fileName;
          savedMime=mime;
          savedBytes=bytes;
          return 'Downloads/$fileName';
        },
      ),
    ));
    await tester.pumpAndSettle();
    final downloadBtn=find.byKey(const Key('photo-detail-download'));
    final fullscreenBtn=find.byKey(const Key('photo-detail-fullscreen'));
    expect(downloadBtn,findsOneWidget);
    expect(fullscreenBtn,findsOneWidget);
    expect(tester.getRect(downloadBtn).left,lessThan(tester.getRect(fullscreenBtn).left));
    expect(find.descendant(of:downloadBtn,matching:find.byType(Text)),findsNothing);

    await tester.tap(downloadBtn);
    await tester.pumpAndSettle();
    expect(savedBytes,galleryPng());
    expect(savedMime,'image/png');
    expect(savedName,endsWith('.png'));
    expect(find.textContaining('기기에 사진을 저장했습니다'),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
