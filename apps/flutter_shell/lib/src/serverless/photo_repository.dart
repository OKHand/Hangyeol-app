import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'client.dart';

Future<Directory> photoAccountDirectory(AppsScriptPlatformClient client,String email) async {
  final base=await getApplicationDocumentsDirectory();
  final scope=sha256.convert(utf8.encode('${client.storageKey}:$email'));
  return Directory('${base.path}/company-photos/$scope');
}

class PhotoFilter {
  const PhotoFilter(this.field,this.value);
  final String field,value;
}
class PhotoCacheStats {
  const PhotoCacheStats(this.files,this.bytes);
  final int files,bytes;
}

const photoFields={'all':'전체','farm':'농가','crop':'작물','variety':'품종','date':'촬영일','region':'주소·지역'};
String photoGroupValue(Map<String,dynamic> photo,String field)=>
  (photo[field] as String? ?? '').trim().isEmpty?'미입력':photo[field] as String;
List<String> photoSuggestions(Map<String,List<String>> values,String field,String query) {
  final options=field=='all'?values.values.expand((v)=>v):values[field]??<String>[];
  final normalized=query.replaceAll(RegExp(r'\s+'),'').toLowerCase();
  return options.toSet().where((v)=>v.replaceAll(RegExp(r'\s+'),'').toLowerCase().contains(normalized)).take(15).toList();
}
bool photoMatches(Map<String,dynamic> photo,String field,String query,{bool exact=false}) {
  final text=field=='all'?['farm','crop','variety','date','region','note'].map((k)=>photo[k]??'').join(' '):photo[field] as String? ?? '';
  final value=text.replaceAll(RegExp(r'\s+'),'').toLowerCase(),needle=query.replaceAll(RegExp(r'\s+'),'').toLowerCase();
  return exact?value==needle:value.contains(needle);
}

class PhotoRepository {
  PhotoRepository(this.client,{this.cacheDirectory,this.onAuthError}):_session=client.token;
  final AppsScriptPlatformClient client;
  final String? _session;
  Directory? cacheDirectory;
  final Future<void> Function(Object)? onAuthError;
  final _memory=<String,Uint8List>{};
  final _loads=<String,Future<Uint8List?>>{};
  final _queue=<String,List<Completer<Uint8List?>>>{};
  Timer? _timer;
  bool _loading=false,_disposed=false;
  DateTime? _lastPrune;
  int _cacheGeneration=0;
  Future<void> _diskWork=Future.value();
  Future<T> _withDisk<T>(Future<T> Function() work){
    final task=_diskWork.then((_)=>work());_diskWork=task.then<void>((_) {},onError:(Object _,StackTrace __) {});return task;
  }
  Future<List<File>> _cacheFiles() async {
    final files=<File>[];final base=cacheDirectory;if(base==null){return files;}
    for(final kind in ['thumb','original']){
      final dir=Directory('${base.path}/$kind');
      if(await FileSystemEntity.type(dir.path,followLinks:false)!=FileSystemEntityType.directory){continue;}
      await for(final entry in dir.list(followLinks:false)){if(entry is File&&entry.path.endsWith('.bin')){files.add(entry);}}
    }return files;
  }
  Future<PhotoCacheStats> cacheStats()=>_withDisk(() async {
    _check();var bytes=0,count=0;for(final file in await _cacheFiles()){try{bytes+=await file.length();count++;}on FileSystemException{/* A file may have been removed by cache eviction. */}}
    return PhotoCacheStats(count,bytes);
  });
  Future<void> clearCache() async {
    _check();_cacheGeneration++;_memory.clear();_loads.clear();client.invalidateReadCache();
    await _withDisk(() async {_check();for(final file in await _cacheFiles()){await file.delete();}_lastPrune=null;});
  }
  void _check(){if(_disposed||_session==null||client.token!=_session){throw PlatformAuthFailure('SESSION_CHANGED','계정이 변경되었습니다. 다시 로그인해 주세요.');}}
  Future<Map<String,dynamic>> list({String query='',String field='all',String groupBy='all',int offset=0,bool force=false,bool exact=false}) {
    _check();
    final params=<String,dynamic>{'query':query,'field':field,'groupBy':groupBy,'offset':offset,if(exact)'match':'exact'};
    if(force){client.invalidateReadCache();}
    return force?client.call('photos.list',params:{...params,'refresh':true}):client.readCached('photos.list',params:params);
  }
  String _key(Map<String,dynamic> photo,String kind)=>'$kind:${photo['id']}:${photo['previewVersion']??photo['id']}';
  File? _disk(String key){final d=cacheDirectory;return d==null?null:File('${d.path}/${key.startsWith('original:')?'original':'thumb'}/${sha256.convert(utf8.encode(key))}.bin');}
  Uint8List? _remember(String key,Uint8List value,int generation){
    if(generation!=_cacheGeneration){return value;}
    _check();_memory.remove(key);_memory[key]=value;
    while(_memory.length>120||_memory.values.fold<int>(0,(n,b)=>n+b.length)>16*1024*1024){_memory.remove(_memory.keys.first);}
    return value;
  }
  Future<Uint8List?> _readDisk(String key,int maxBytes,int generation)=>_withDisk(() async {
    try{final file=_disk(key);if(file==null||!await file.exists()){return null;}
      if(await file.length()>maxBytes||DateTime.now().difference(await file.lastModified())>const Duration(days:30)){await file.delete();return null;}
      final bytes=await file.readAsBytes();return _remember(key,bytes,generation);
    }catch(_){return null;}
  });
  Future<void> _writeDisk(String key,Uint8List bytes,int generation)=>_withDisk(() async {
    _check();if(generation!=_cacheGeneration){return;}final file=_disk(key);if(file==null){return;}
    try{await file.parent.create(recursive:true);_check();await file.writeAsBytes(bytes,flush:true);await _pruneDisk();}catch(_){/* Disk cache is optional. */}
  });
  Future<void> _pruneDisk() async {
    final base=cacheDirectory;if(base==null||_lastPrune!=null&&DateTime.now().difference(_lastPrune!)<const Duration(minutes:1)){return;}
    _lastPrune=DateTime.now();
    for(final kind in ['thumb','original']){
      final dir=Directory('${base.path}/$kind');if(!await dir.exists()){continue;}
      final files=await dir.list().where((e)=>e is File&&e.path.endsWith('.bin')).cast<File>().toList();
      final records=<({File file,int size,DateTime changed})>[];
      for(final f in files){try{final stat=await f.stat();records.add((file:f,size:stat.size,changed:stat.modified));}catch(_){}}
      records.sort((a,b)=>b.changed.compareTo(a.changed));var total=0;
      for(var i=0;i<records.length;i++){total+=records[i].size;
        if(i>=(kind=='thumb'?120:8)||total>(kind=='thumb'?32:64)*1024*1024){try{await records[i].file.delete();}catch(_){}}
      }
    }
  }
  Future<Uint8List?> thumbnail(Map<String,dynamic> photo) {
    _check();final key=_key(photo,'thumb'),cached=_memory.remove(key);
    if(cached!=null){_memory[key]=cached;return Future.value(cached);}
    final generation=_cacheGeneration,loadKey='$_cacheGeneration:$key';
    return _loads.putIfAbsent(loadKey,()=>_loadThumbnail(photo,key,generation).whenComplete((){_loads.remove(loadKey);}));
  }
  Future<Uint8List?> _loadThumbnail(Map<String,dynamic> photo,String key,int generation) async {
    final disk=await _readDisk(key,262144,generation);_check();if(disk!=null){return disk;}
    final completer=Completer<Uint8List?>();
    _queue.putIfAbsent(photo['id'] as String,()=>[]).add(completer);_schedule();
    final bytes=await completer.future;_check();
    if(bytes!=null){_remember(key,bytes,generation);await _writeDisk(key,bytes,generation);}_check();return bytes;
  }
  void _schedule(){if(_disposed||_loading||_timer!=null||_queue.isEmpty){return;}_timer=Timer(const Duration(milliseconds:30),(){_timer=null;_flush();});}
  Future<void> _flush() async {
    if(_loading||_disposed||_queue.isEmpty){return;}_loading=true;
    final ids=_queue.keys.take(8).toList(),waiting={for(final id in ids)id:_queue.remove(id)!};
    try{_check();final response=await client.call('photos.thumbnails',params:{'ids':ids});_check();
      final values=List<Map<String,dynamic>>.from(response['thumbnails'] as List);
      for(final id in ids){Uint8List? bytes;final matches=values.where((v)=>v['id']==id&&v['ready']==true);
        if(matches.isNotEmpty){final encoded=matches.first['base64'];if(encoded is String&&encoded.length<=349528){final data=base64Decode(encoded);if(data.length<=262144){bytes=data;}}}
        for(final completer in waiting[id]!){completer.complete(bytes);}
      }
    }catch(error){for(final group in waiting.values){for(final c in group){if(!c.isCompleted){c.completeError(error);}}}
      if(error is PlatformAuthFailure&&['AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'].contains(error.code)){try{await onAuthError?.call(error);}catch(_){}}
    }finally{_loading=false;_schedule();}
  }
  Future<void> rememberThumbnail(Map<String,dynamic> photo,Uint8List bytes) async {
    _check();final generation=_cacheGeneration,key=_key(photo,'thumb');_remember(key,bytes,generation);await _writeDisk(key,bytes,generation);
  }
  Future<Uint8List> original(Map<String,dynamic> photo) async {
    _check();final generation=_cacheGeneration,key=_key(photo,'original'),memory=_memory[key];if(memory!=null){return memory;}
    final disk=await _readDisk(key,8*1024*1024,generation);_check();if(disk!=null){return disk;}
    final response=await client.call('photos.download',params:{'id':photo['id']});_check();
    final encoded=response['base64'];if(encoded is! String||encoded.length>11184812){throw PlatformAuthFailure('PHOTO_SIZE','사진 크기를 확인해 주세요.');}
    final bytes=base64Decode(encoded);_remember(key,bytes,generation);await _writeDisk(key,bytes,generation);_check();return bytes;
  }
  void dispose(){_disposed=true;_timer?.cancel();_memory.clear();for(final group in _queue.values){for(final c in group){c.completeError(PlatformAuthFailure('SESSION_CHANGED','사진 화면이 닫혔습니다.'));}}_queue.clear();}
}
