import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';
import 'package:hangyeol_platform/src/serverless/photo_store.dart';
import 'gallery_test_data.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('preview scales a large image without changing its original',() async {
    final recorder=ui.PictureRecorder();final canvas=ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xff207050),ui.BlendMode.src);
    final picture=recorder.endRecording(),image=await picture.toImage(1200,800);
    final data=(await image.toByteData(format:ui.ImageByteFormat.png))!;
    final original=data.buffer.asUint8List(data.offsetInBytes,data.lengthInBytes),saved=Uint8List.fromList(original);
    final preview=await createPhotoPreview(original);expect(preview,isNotNull);expect(original,saved);
    final codec=await ui.instantiateImageCodec(preview!),frame=await codec.getNextFrame();
    expect(frame.image.width,240);expect(frame.image.height,160);expect(preview.length,lessThanOrEqualTo(262144));
    frame.image.dispose();codec.dispose();image.dispose();picture.dispose();
  });
  test('eleven drafts survive restart with stable batch indexes and clean up only confirmed copies',() async {
    final directory=await Directory.systemTemp.createTemp('gallery-batch-');
    addTearDown(()=>directory.delete(recursive:true));
    final original=File('${directory.path}/original.png');await original.writeAsBytes(galleryPng());
    final store=PhotoDraftStore(Directory('${directory.path}/alice'));
    final drafts=await store.addBatch(List.filled(11,original),{'farm':'나상 가명A종묘','crop':'토마토'},[]);
    expect(drafts.map((d)=>d['requestId']).toSet(),hasLength(11));expect(drafts.map((d)=>d['batchId']).toSet(),hasLength(1));
    expect(drafts.map((d)=>d['batchIndex']),List.generate(11,(i)=>i));expect(drafts.every((d)=>d['batchSize']==11&&d['date']==''),isTrue);
    final restored=await PhotoDraftStore(store.directory).load();expect(restored,drafts);
    final id=restored.first['requestId'] as String;expect(await store.originalBytes(id),galleryPng());expect(await store.previewBytes(id),isNotNull);
    restored.first['status']='stored';final remaining=await store.removeStored(restored);
    expect(remaining,hasLength(10));expect(await store.file(id).exists(),isFalse);expect(await original.readAsBytes(),galleryPng());
    expect(await store.file(remaining.first['requestId'] as String).exists(),isTrue);
    expect(await PhotoDraftStore(Directory('${directory.path}/bob')).load(),isEmpty);
  });
  test('a bad file rolls back its new batch and preserves existing retries and source files',() async {
    final directory=await Directory.systemTemp.createTemp('gallery-rollback-');addTearDown(()=>directory.delete(recursive:true));
    final original=File('${directory.path}/original.png'),invalid=File('${directory.path}/invalid.txt');
    await original.writeAsBytes(galleryPng());await invalid.writeAsString('not a photo');
    final store=PhotoDraftStore(Directory('${directory.path}/queue'));
    final existing=await store.addBatch([original],{'farm':'기존','crop':'토마토'},[]);
    await expectLater(store.addBatch([original,invalid],{'farm':'새 농가','crop':'토마토'},existing),throwsA(isA<PlatformAuthFailure>()));
    expect(await store.load(),existing);
    expect(await store.directory.list().where((f)=>f.path.endsWith('.photo')).length,1);
    expect(await original.exists(),isTrue);expect(await invalid.exists(),isTrue);
  });
}
