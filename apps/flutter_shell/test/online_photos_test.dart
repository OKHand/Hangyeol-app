import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';
import 'package:hangyeol_platform/src/serverless/photos.dart';
void main(){
 test('photo drafts copy original bytes, survive restart and retain retry ID per account directory',() async {
   final base=await Directory.systemTemp.createTemp('online-photo-test-');
   addTearDown(()=>base.delete(recursive:true));
   final source=File('${base.path}/source.jpg');await source.writeAsBytes([255,216,255,1]);
   final alice=PhotoDraftStore(Directory('${base.path}/alice'));await alice.load();
   final draft=await alice.add(source,{'farm':'가명A농가','crop':'토마토'},[]);
   await source.delete();
   final restored=PhotoDraftStore(alice.directory),rows=await restored.load();
   expect(rows.single['requestId'],draft['requestId']);
   expect(await restored.file(rows.single['requestId'] as String).readAsBytes(),[255,216,255,1]);
   expect(await PhotoDraftStore(Directory('${base.path}/bob')).load(),isEmpty);
   expect(()=>restored.file('../other-user'),throwsFormatException);
 });
 test('photo upload uses authenticated API body, no webhook or Google credential in client',() async {
   final mock=MockClient((request)async{
     final body=jsonDecode(request.body) as Map<String,dynamic>;
     expect(body['action'],'photos.upload');expect(body['token'],'a'*64);
     expect((body['params'] as Map)['requestId'],'stable-id');
     expect(request.url.host,'script.google.com');
     return http.Response(jsonEncode({'ok':true,'result':{'photo':{'id':'saved','state':'stored','notification':'pending'}}}),200);
   });
   final client=AppsScriptPlatformClient(Uri.parse('https://script.google.com/macros/s/photo-test/exec'),client:mock)..token='a'*64;
   addTearDown(client.close);
   final r=await client.call('photos.upload',params:{'requestId':'stable-id','base64':base64Encode([255,216,255,1])});
   expect((r['photo'] as Map)['notification'],'pending');
   expect(photoNotificationLabel('uncertain'),'Discord 채널 확인 필요');
 });
}
