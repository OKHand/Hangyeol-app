import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:uuid/uuid.dart';
import '../demo/demo_photo_metadata.dart';
import 'client.dart';

Future<Uint8List?> createPhotoPreview(Uint8List bytes) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer=await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor=await ui.ImageDescriptor.encoded(buffer);
    final factor=math.min(1.0,240/math.max(descriptor.width,descriptor.height));
    codec=await descriptor.instantiateCodec(targetWidth:math.max(1,(descriptor.width*factor).round()),
      targetHeight:math.max(1,(descriptor.height*factor).round()));
    image=(await codec.getNextFrame()).image;
    final data=await image.toByteData(format:ui.ImageByteFormat.png);
    if(data==null||data.lengthInBytes>262144){return null;}
    return data.buffer.asUint8List(data.offsetInBytes,data.lengthInBytes);
  }catch(_){return null;}
  finally{image?.dispose();codec?.dispose();descriptor?.dispose();buffer?.dispose();}
}

bool supportedPhotoBytes(Uint8List bytes) {
  if(bytes.length<4){return false;}
  final hex=bytes.take(16).map((b)=>b.toRadixString(16).padLeft(2,'0')).join();
  return hex.startsWith('ffd8ff')||hex.startsWith('89504e470d0a1a0a')||
    hex.startsWith('52494646')&&hex.length>=24&&hex.substring(16,24)=='57454250'||
    hex.length>=24&&hex.substring(8,16)=='66747970'&&RegExp('68656963|68656978|6d696631').hasMatch(hex.substring(16));
}

class PhotoDraftStore {
  PhotoDraftStore(this.directory);
  final Directory directory;
  Future<List<Map<String,dynamic>>> load() async {
    await directory.create(recursive:true);
    final index=File('${directory.path}/queue.json');
    if(!await index.exists()){return [];}
    return (jsonDecode(await index.readAsString()) as List).map((r)=>Map<String,dynamic>.from(r as Map)).toList();
  }
  Future<void> save(List<Map<String,dynamic>> drafts) async {
    await directory.create(recursive:true);
    final pending=File('${directory.path}/queue.json.pending');
    await pending.writeAsString(jsonEncode(drafts),flush:true);
    await pending.rename('${directory.path}/queue.json');
  }
  File file(String id){if(!RegExp(r'^[a-f0-9-]{36}$').hasMatch(id)){throw const FormatException('Invalid photo ID');}return File('${directory.path}/$id.photo');}
  File previewFile(String id){file(id);return File('${directory.path}/$id.preview');}
  Future<Uint8List> originalBytes(String id)=>file(id).readAsBytes();
  Future<Uint8List?> previewBytes(String id) async {final f=previewFile(id);return await f.exists()?f.readAsBytes():null;}
  Future<Map<String,dynamic>> add(File original,Map<String,dynamic> meta,List<Map<String,dynamic>> drafts) async {
    return (await addBatch([original],meta,drafts)).single;
  }
  Future<List<Map<String,dynamic>>> addBatch(List<File> originals,Map<String,dynamic> meta,List<Map<String,dynamic>> drafts,
    {bool camera=false,void Function(int,int)? onProgress}) async {
    if(originals.isEmpty||originals.length>100){throw PlatformAuthFailure('PHOTO_COUNT','한 번에 사진을 1~100장 선택해 주세요.');}
    await directory.create(recursive:true);
    final created=<Map<String,dynamic>>[],copied=<File>[],batchId=const Uuid().v4();
    try {
      for(var i=0;i<originals.length;i++){
        final original=originals[i];
        if(await original.length()>8*1024*1024){throw PlatformAuthFailure('PHOTO_SIZE','사진 한 장은 최대 8MB입니다.');}
        final bytes=await original.readAsBytes();
        if(!supportedPhotoBytes(bytes)){throw PlatformAuthFailure('INVALID_PHOTO','JPG·PNG·WEBP·HEIC 사진을 선택해 주세요.');}
        final id=const Uuid().v4(),target=file(id);
        await original.copy(target.path);copied.add(target);
        final preview=await createPhotoPreview(bytes);
        if(preview!=null){final f=previewFile(id);await f.writeAsBytes(preview,flush:true);copied.add(f);}
        var date=meta['date'] as String? ?? '';
        if(date.isEmpty){date=(await DemoPhotoMetadata.read(original,camera:camera)).date;}
        created.add({...meta,'date':date,'requestId':id,'batchId':batchId,'batchSize':originals.length,'batchIndex':i,
          'status':'pending','createdAt':DateTime.now().toUtc().toIso8601String()});
        onProgress?.call(i+1,originals.length);
      }
      await save([...drafts,...created]);return created;
    }catch(_){for(final f in copied){try{if(await f.exists()){await f.delete();}}catch(_){}}rethrow;}
  }
  Future<List<Map<String,dynamic>>> removeStored(List<Map<String,dynamic>> drafts) async {
    final pending=drafts.where((d)=>d['status']!='stored').toList();
    await save(pending);
    for(final draft in drafts.where((d)=>d['status']=='stored')){
      final id=draft['requestId'] as String;
      for(final f in [file(id),previewFile(id)]){try{if(await f.exists()){await f.delete();}}catch(_){}}
    }
    return pending;
  }
}
