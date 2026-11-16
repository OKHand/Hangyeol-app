import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hangyeol_platform/src/api.dart';
import 'package:hangyeol_platform/src/upload_queue.dart';

void main(){
  test('persisted photo retries retain the request ID after a failed finalization',()async{
    final directory=await Directory.systemTemp.createTemp('hangyeol-queue-test-');
    try{
      final reservations=<String>[];var completions=0,puts=0;
      final api=NativeApi(Uri.parse('http://localhost:8787'),client:MockClient((request)async{
        if(request.method=='PUT'){puts++;return http.Response('',204);}
        if(request.url.path.endsWith('/complete')){
          completions++;
          return completions==1?http.Response(jsonEncode({'error':{'code':'RETRYABLE','message':'다시 시도'}}),503):http.Response(jsonEncode({'photo':{'id':'photo-1'}}),200);
        }
        reservations.add((jsonDecode(request.body)as Map)['clientRequestId'] as String);
        return http.Response(jsonEncode({'id':'upload-1','uploadUrl':'/v1/upload-sessions/upload-1/content','status':puts>0?'uploaded':'pending'}),200);
      }))..token='session-a'..userId='user-a';
      final source=File('${directory.path}/source.jpg');await source.writeAsBytes([1,2,3]);
      final first=UploadQueue(api,directory:Directory('${directory.path}/queue'));
      await first.initialize();
      final asset=await first.importFile(source.path);
      // Even the unqueued selected draft survives app termination.
      final restored=UploadQueue(api,directory:Directory('${directory.path}/queue'));await restored.initialize();
      final entry=await restored.enqueue(asset.handle,{'farmName':'시험농가','capturedAt':null});
      await restored.retry();expect(restored.status().single['state'],'failed');
      final afterRestart=UploadQueue(api,directory:Directory('${directory.path}/queue'));await afterRestart.initialize();
      expect(afterRestart.status().single['id'],entry.id);
      await afterRestart.retry();expect(afterRestart.status().single['state'],'complete');
      expect(reservations,[entry.id,entry.id]);expect(puts,1);
      api.userId='user-b';expect(afterRestart.status(),isEmpty);
    }finally{await directory.delete(recursive:true);}
  });
  test('switching accounts during reservation stops prior account upload',()async{
    final directory=await Directory.systemTemp.createTemp('hangyeol-session-test-');
    final reserved=Completer<void>(),release=Completer<void>();var uploads=0;
    try{
      final api=NativeApi(Uri.parse('http://localhost:8787'),client:MockClient((request)async{
        if(request.method=='PUT'){uploads++;return http.Response('',204);}
        reserved.complete();await release.future;
        return http.Response(jsonEncode({'id':'pending','uploadUrl':'/v1/upload-sessions/pending/content','status':'pending'}),200);
      }))..token='old-session'..userId='old-user';
      final queue=UploadQueue(api,directory:Directory('${directory.path}/queue'));await queue.initialize();
      final source=File('${directory.path}/sample.jpg');await source.writeAsBytes([1]);
      final asset=await queue.importFile(source.path);await queue.enqueue(asset.handle,{'farmName':'이전 계정 농가'});
      final running=queue.retry();await reserved.future;
      api.clearSession();api.token='new-session';api.userId='new-user';release.complete();await running;
      expect(uploads,0);expect(queue.status(),isEmpty);
      api.userId='old-user';expect(queue.status().single['state'],'queued');
    }finally{await directory.delete(recursive:true);}
  });
  test('adding a photo during an upload is deferred safely to the next retry',()async{
    final directory=await Directory.systemTemp.createTemp('hangyeol-concurrent-test-');
    final reserved=Completer<void>(),release=Completer<void>();var reservations=0;
    try{
      final api=NativeApi(Uri.parse('http://localhost:8787'),client:MockClient((request)async{
        if(request.method=='PUT'){return http.Response('',204);}
        if(request.url.path.endsWith('/complete')){return http.Response(jsonEncode({'photo':{'id':'photo-$reservations'}}),200);}
        reservations++;
        if(reservations==1){reserved.complete();await release.future;}
        return http.Response(jsonEncode({'id':'upload-$reservations','uploadUrl':'/v1/upload-sessions/upload-$reservations/content','status':'pending'}),200);
      }))..token='session'..userId='user';
      final queue=UploadQueue(api,directory:Directory('${directory.path}/queue'));await queue.initialize();
      final source=File('${directory.path}/sample.jpg');await source.writeAsBytes([1]);
      final first=await queue.importFile(source.path);await queue.enqueue(first.handle,{'farmName':'첫 사진'});
      final running=queue.retry();await reserved.future;
      final second=await queue.importFile(source.path);await queue.enqueue(second.handle,{'farmName':'둘째 사진'});
      release.complete();await running;
      expect(queue.status().map((entry)=>entry['state']).toList(),['complete','queued']);
      await queue.retry();
      expect(queue.status().map((entry)=>entry['state']).toList(),['complete','complete']);
      expect(reservations,2);
    }finally{await directory.delete(recursive:true);}
  });
  test('upload rejects external URLs before sending bearer credentials',()async{
    var contacted=false;
    final api=NativeApi(Uri.parse('https://api.example'),client:MockClient((request)async{contacted=true;return http.Response('',204);}))..token='private';
    await expectLater(api.upload('https://other.example/upload',[1],'image/jpeg'),throwsA(isA<ApiFailure>()));
    expect(contacted,isFalse);
  });
  test('logout accepts a successful empty response',()async{
    final api=NativeApi(Uri.parse('https://api.example'),client:MockClient((request)async=>http.Response('',204)));
    expect(await api.request('/v1/auth/logout',method:'POST',body:{}),isEmpty);
  });
}
