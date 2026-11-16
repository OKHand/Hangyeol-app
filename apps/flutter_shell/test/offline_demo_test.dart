import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/demo/demo_app.dart';
import 'package:hangyeol_platform/src/demo/demo_store.dart';
import 'package:hangyeol_platform/src/demo/demo_photo_metadata.dart';
import 'package:hangyeol_platform/src/demo/demo_photos.dart';
class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context)=>throw StateError('Offline demo attempted network access');
}
void main(){
  late Directory directory;
  late DemoStore store;
  setUp(()async{directory=await Directory.systemTemp.createTemp('hangyeol-demo-test-');store=DemoStore(Directory('${directory.path}/demo'),seedSamples:false);await store.load();});
  tearDown(()async{await directory.delete(recursive:true);});
  final parity=jsonDecode(File('assets/erp-parity.json').readAsStringSync()) as List;
  for(final (index,value) in parity.indexed){
    test('web ERP comparison ${index+1}: ${value['params']}',(){
      final p=value['params'] as Map;
      String tokens(String key)=>(p[key] as List?)?.join(', ')??'';
      final report=DemoQuery(mode:p['mode'] as String,customer:tokens('customers'),div:tokens('divs'),item:tokens('items'),sales:tokens('sales'),origin:tokens('origins'),view:p['view'] as String? ?? 'A',groupBy:p['groupBy'] as String? ?? 'detail',start:DateTime.tryParse(p['startDate'] as String? ?? ''),end:DateTime.tryParse(p['endDate'] as String? ?? '')).report();
      final original=value['result'] as Map;
      if(original['success']!=true){expect(report.rows,isEmpty);return;}
      final data=original['data'] as List;
      expect(report.columns,List<String>.from(data[1] as List));
      List<List<String>> canonical(List<List<String>> rows){
        final output=rows.map((r)=>r.map((cell)=>cell=='-0'?'0':cell).toList()).toList();
        // The offline fixture freezes elapsed days at its stated reference day.
        if(p['mode']=='요약'){for(final row in output){row[13]='';}}
        if(p['mode']=='집계'||p['mode']=='재고'){output.sort((a,b)=>a.join('|').compareTo(b.join('|')));}
        return output;
      }
      expect(canonical(report.rows),canonical(data.skip(2).map((r)=>List<String>.from(r as List)).toList()));
    });
  }
  test('number precision and calendar validation',(){
    expect(demoNumber(1000),'1,000');expect(demoNumber(.125),'0.125');expect(demoNumber(-12000.5),'-12,000.5');
    expect(()=>DemoQuery(start:DateTime(2026,11,10),end:DateTime(2026,11,1)).report(),throwsArgumentError);
    expect(const DemoQuery(mode:'출고',customer:'가 명 A').report().rows,isNotEmpty);
  });
  test('photo EXIF time and GPS are read without assigning today to an old image',(){
    final m=DemoPhotoMetadata.parse({'EXIF DateTimeOriginal':'2026:10:21 14:25:10','GPS GPSLatitude':'[37, 30, 0]','GPS GPSLatitudeRef':'N','GPS GPSLongitude':'[127, 15, 0]','GPS GPSLongitudeRef':'E'});
    expect(m.date,'2026-10-21');expect(m.time,'14:25');expect(m.latitude,37.5);expect(m.longitude,127.25);expect(m.dateSource,'exif');
    expect(DemoPhotoMetadata.parse({}).date,isEmpty);expect(DemoPhotoMetadata.parse({'EXIF DateTimeOriginal':'2026:02:30 00:00:00'}).date,isEmpty);
  });
  test('photo copies, complete metadata, edits and local integration previews survive restart',()async{
    final original=File('${directory.path}/gallery.png');await original.writeAsBytes([137,80,78,71]);
    await store.add(source:original,title:'시험포',farmName:'한결농장',crop:'토마토',variety:'체험 루비',location:'담양 시험포',note:'생육 양호',date:'2026-11-03',time:'09:20',dateSource:'exif',latitude:35.1,longitude:126.9,locationSource:'exif');
    final p=store.photos.single;
    expect(p.needsInfo,isFalse);expect(await store.photoFile(p).readAsBytes(),[137,80,78,71]);
    await store.simulateIntegrations(p);
    final reopened=DemoStore(store.directory,seedSamples:false);await reopened.load();
    expect(reopened.photos.single.farmName,'한결농장');expect(reopened.photos.single.latitude,35.1);expect(reopened.jobs.length,2);expect(reopened.jobs.every((j)=>j['status']=='demo'),isTrue);
    final changed=DemoPhoto.fromJson({...p.toJson(),'note':'다음 주 확인','crop':''});await reopened.update(changed);await store.load();expect(store.photos.single.note,'다음 주 확인');expect(store.photos.single.needsInfo,isTrue);
    await store.remove(store.photos.single);expect(await store.photoFile(p).exists(),isFalse);expect(await original.exists(),isTrue);
    await store.reset(restoreSamples:true);expect(store.photos.length,3);expect(store.jobs,isEmpty);expect(await original.exists(),isTrue);
  });
  test('photo filters distinguish captured date, created date and incomplete information',(){
    final p=demoSamplePhotos.first;
    expect(const DemoPhotoFilter(farm:'한결',crop:'토마토',region:'담양',status:'ready').matches(p),isTrue);
    expect(DemoPhotoFilter(start:DateTime(2026,11,4),end:DateTime(2026,11,4)).matches(p),isFalse);
    expect(DemoPhotoFilter(dateBasis:'created',start:DateTime(2026,11,4),end:DateTime(2026,11,4)).matches(p),isTrue);
    expect(const DemoPhotoFilter(status:'needs_info').matches(demoSamplePhotos.last),isTrue);
    expect(DemoPhoto.fromJson({...p.toJson(),'date':''}).needsInfo,isTrue);
    expect(DemoPhotoFilter(start:DateTime(2020)).matches(demoSamplePhotos.last),isFalse);
  });
  test('old demo records migrate without deleting originals or overwriting an unreadable index',()async{
    final legacy={'id':'legacy1','fileName':'ab.jpg','title':'이전 기록','variety':'루비','location':'시험포','note':'보존','date':'2026-11-01'};
    final index=File('${store.directory.path}/photos.json');await index.writeAsString(jsonEncode([legacy]));await store.load();expect(store.photos.single.note,'보존');expect(store.photos.single.farmName,isEmpty);expect(store.photos.single.dateSource,'manual');
    await index.writeAsString('invalid');await expectLater(store.load(),throwsFormatException);expect(await index.readAsString(),'invalid');expect(()=>DemoPhoto.fromJson({'fileName':'../private.jpg'}),throwsFormatException);
  });
  testWidgets('phone starts without server and full ERP filters render results in the app', (tester)async{
    final original=HttpOverrides.current;HttpOverrides.global=_NoNetwork();addTearDown((){HttpOverrides.global=original;});
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(OfflineDemoApp(store:store));await tester.pumpAndSettle();
    expect(find.text('오프라인 체험'),findsOneWidget);expect(find.text('개발 환경 연결'),findsNothing);
    await tester.tap(find.text('ERP').last);await tester.pumpAndSettle();expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip,'출고')).selected,isTrue);
    await tester.enterText(find.byKey(const Key('demo-customer')),'가명A종묘');await tester.pumpAndSettle();expect(find.text('나상 가명A종묘'),findsOneWidget);
    await tester.tap(find.text('나상 가명A종묘'));await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('demo-query')));await tester.tap(find.byKey(const Key('demo-query')));await tester.pumpAndSettle();expect(find.byType(DataTable),findsOneWidget);expect(find.textContaining('결과 8건'),findsOneWidget);
    await tester.tap(find.text('조회 조건'));await tester.pumpAndSettle();expect(tester.widget<TextField>(find.byKey(const Key('demo-customer'))).controller!.text,contains('나상 가명A종묘'));
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('photo information editing changes incomplete status and survives reopening', (tester)async{
    await tester.runAsync(() async { await store.reset(restoreSamples:true); await store.update(DemoPhoto.fromJson({...store.photos.last.toJson(),'date':'2026-11-06','dateSource':'manual'})); });
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>Scaffold(body:TextButton(onPressed:()=>Navigator.of(context).push<void>(MaterialPageRoute(builder:(_)=>DemoPhotoEditor(store:store,photo:store.photos.last))),child:const Text('사진 수정 열기'))))));
    await tester.tap(find.text('사진 수정 열기'));await tester.pumpAndSettle();
    expect(find.text('농가명'),findsOneWidget);expect(find.text('작물'),findsOneWidget);
    final field=find.byType(TextFormField).first;await tester.enterText(field,'보완한 체험농장');
    await tester.scrollUntilVisible(find.byKey(const Key('photo-save')),300,scrollable:find.byType(Scrollable).first);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('photo-save')));
      for(var i=0;i<100&&store.photos.last.farmName!='보완한 체험농장';i++){await Future<void>.delayed(const Duration(milliseconds:10));}
      await store.load();
    });
    await tester.pumpAndSettle();expect(store.photos.last.farmName,'보완한 체험농장');expect(store.photos.last.needsInfo,isFalse);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
  });
}
