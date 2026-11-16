import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';
import 'package:hangyeol_platform/src/serverless/photo_repository.dart';
import 'gallery_test_data.dart';

const endpoint='https://script.google.com/macros/s/gallery-test/exec';
http.Response answer(Map<String,dynamic> value)=>http.Response(jsonEncode({'ok':true,'result':value}),200,headers:const {'content-type':'application/json; charset=utf-8'});
void main(){
  test('catalog cache coalesces requests, copies results and invalidates after upload or account change',() async {
    var calls=0;
    final client=AppsScriptPlatformClient(Uri.parse(endpoint),client:MockClient((request)async{
      calls++;return answer({'photos':[{'id':'photo-$calls'}]});
    }))..token='a'*64;
    addTearDown(client.close);
    final results=await Future.wait([client.readCached('photos.list'),client.readCached('photos.list')]);
    expect(calls,1);(results.first['photos'] as List).clear();
    expect((await client.readCached('photos.list'))['photos'],isNotEmpty);
    await client.call('photos.upload');await client.readCached('photos.list');expect(calls,3);
    client.token='b'*64;await client.readCached('photos.list');expect(calls,4);
    await client.readCached('photos.list',force:true);expect(calls,5);
    await expectLater(client.readCached('photos.download'),throwsArgumentError);
    await client.call('photos.updateMany');await client.readCached('photos.list');expect(calls,7);
  });
  test('late private response from an old session is rejected and cannot populate the new cache',() async {
    final pending=Completer<http.Response>();var calls=0;
    final client=AppsScriptPlatformClient(Uri.parse(endpoint),client:MockClient((request)async{
      calls++;return calls==1?pending.future:answer({'photos':['new account']});
    }))..token='a'*64;
    addTearDown(client.close);
    final old=client.readCached('photos.list');
    final rejected=expectLater(old,throwsA(isA<PlatformAuthFailure>().having((e)=>e.code,'code','SESSION_CHANGED')));
    await Future<void>.delayed(Duration.zero);client.token='b'*64;
    pending.complete(answer({'photos':['old account']}));await rejected;
    expect((await client.readCached('photos.list'))['photos'],['new account']);expect(calls,2);
  });
  test('thumbnail requests are coalesced into batches of eight and cached on disk without original downloads',() async {
    final directory=await Directory.systemTemp.createTemp('gallery-cache-');
    addTearDown(()=>directory.delete(recursive:true));
    final batches=<List<String>>[];var originals=0;
    final client=AppsScriptPlatformClient(Uri.parse(endpoint),client:MockClient((request)async{
      final body=jsonDecode(request.body) as Map;
      if(body['action']=='photos.download'){originals++;return answer({'base64':base64Encode(galleryPng())});}
      expect(body['action'],'photos.thumbnails');
      final ids=List<String>.from(body['params']['ids'] as List);batches.add(ids);
      return answer({'thumbnails':ids.map((id)=>{'id':id,'ready':true,'base64':base64Encode(galleryPng()),'mime':'image/png'}).toList()});
    }))..token='a'*64;
    addTearDown(client.close);
    final repository=PhotoRepository(client);
    final photos=List.generate(19,galleryPhoto);
    final bytes=await Future.wait([...photos.map(repository.thumbnail),repository.thumbnail(photos.first)]);
    expect(bytes.every((b)=>b!=null&&b.length==galleryPng().length),isTrue);
    expect(batches.map((b)=>b.length),[8,8,3]);expect(originals,0);
    await repository.thumbnail(photos.first);expect(batches.length,3);
    repository.cacheDirectory=directory;await repository.rememberThumbnail(photos.first,galleryPng());
    await repository.original(photos.first);await repository.original(photos.first);expect(originals,1);
    repository.dispose();
    final reopened=PhotoRepository(client,cacheDirectory:directory);
    expect(await reopened.thumbnail(photos.first),galleryPng());
    expect(await reopened.original(photos.first),galleryPng());expect(batches.length,3);expect(originals,1);
    reopened.dispose();
    final other=PhotoRepository(client,cacheDirectory:Directory('${directory.path}/other-account'));
    await other.thumbnail(photos.first);expect(batches.length,4);other.dispose();
  });
  test('local suggestions cover date, address, variety and partial farm names',(){
    const values={'farm':['나상 가명A종묘'],'variety':['루비'],'date':['2026-11-01'],'region':['강원 춘천']};
    expect(photoSuggestions(values,'farm','가명A'),['나상 가명A종묘']);
    expect(photoSuggestions(values,'all','2026-11'),['2026-11-01']);
    expect(photoSuggestions(values,'region','강원춘천'),['강원 춘천']);
    expect(photoSuggestions(values,'variety','가명A'),isEmpty);
    expect(photoMatches(galleryPhoto(0),'date','2026-11'),isTrue);
  });
  test('clear removes only account photo caches and refetches while preserving pending files',() async {
    final directory=await Directory.systemTemp.createTemp('photo-cache-clear-');addTearDown(()=>directory.delete(recursive:true));
    final cache=Directory('${directory.path}/account/cache');await cache.create(recursive:true);
    final pending=File('${directory.path}/account/queued.photo');await pending.writeAsString('unuploaded original');
    final index=File('${directory.path}/account/queue.json');await index.writeAsString('pending request ID');
    final other=File('${directory.path}/other/cache/thumb/other.bin');await other.parent.create(recursive:true);await other.writeAsString('other account');
    var calls=0;
    final client=AppsScriptPlatformClient(Uri.parse(endpoint),client:MockClient((request)async{
      calls++;final body=jsonDecode(request.body) as Map;
      if(body['action']=='photos.download'){return answer({'base64':base64Encode(galleryPng())});}
      return answer({'thumbnails':[{'id':galleryPhoto(0)['id'],'ready':true,'base64':base64Encode(galleryPng())}]});
    }))..token='a'*64;addTearDown(client.close);
    final repository=PhotoRepository(client,cacheDirectory:cache);addTearDown(repository.dispose);
    await repository.thumbnail(galleryPhoto(0));await repository.original(galleryPhoto(0));
    expect((await repository.cacheStats()).files,2);expect(calls,2);
    await repository.clearCache();expect((await repository.cacheStats()).files,0);
    expect(await pending.readAsString(),'unuploaded original');expect(await index.readAsString(),'pending request ID');expect(await other.readAsString(),'other account');
    await repository.thumbnail(galleryPhoto(0));await repository.original(galleryPhoto(0));expect(calls,4);
  });
  test('a thumbnail response already in flight cannot refill a cache that was cleared',() async {
    final directory=await Directory.systemTemp.createTemp('photo-cache-race-');addTearDown(()=>directory.delete(recursive:true));
    final started=Completer<void>(),reply=Completer<http.Response>();var calls=0;
    final client=AppsScriptPlatformClient(Uri.parse(endpoint),client:MockClient((request)async{
      calls++;if(calls==1){started.complete();return reply.future;}
      return answer({'thumbnails':[{'id':galleryPhoto(0)['id'],'ready':true,'base64':base64Encode(galleryPng())}]});
    }))..token='a'*64;addTearDown(client.close);
    final repository=PhotoRepository(client,cacheDirectory:directory);addTearDown(repository.dispose);
    final loading=repository.thumbnail(galleryPhoto(0));await started.future;
    await repository.clearCache();reply.complete(answer({'thumbnails':[{'id':galleryPhoto(0)['id'],'ready':true,'base64':base64Encode(galleryPng())}]}));
    expect(await loading,galleryPng());expect((await repository.cacheStats()).files,0);
    await repository.thumbnail(galleryPhoto(0));expect(calls,2);expect((await repository.cacheStats()).files,1);
  });

}
