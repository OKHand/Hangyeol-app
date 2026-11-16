import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'api.dart';

/// The file is owned by the application, never an ephemeral camera/cache path.
class LocalAsset {
  LocalAsset({required this.handle, required this.path, required this.fileName, required this.contentType, required this.size, this.capturedAt});
  final String handle, path, fileName, contentType;
  final int size;
  final String? capturedAt;
  Map<String, dynamic> toJson() => {'handle':handle,'path':path,'fileName':fileName,'contentType':contentType,'size':size,'capturedAt':capturedAt};
  factory LocalAsset.fromJson(Map<String, dynamic> data) => LocalAsset(handle:data['handle'] as String,path:data['path'] as String,fileName:data['fileName'] as String,contentType:data['contentType'] as String,size:data['size'] as int,capturedAt:data['capturedAt'] as String?);
  Map<String, dynamic> publicView() => {'handle':handle,'fileName':fileName,'contentType':contentType,'size':size,'capturedAt':capturedAt,'capturedAtSource':capturedAt==null?'unknown':'device'};
}

class QueueEntry {
  QueueEntry({required this.id, required this.ownerId, required this.asset, required this.metadata, this.state='queued', this.error, this.photo});
  final String id, ownerId;
  final LocalAsset asset;
  final Map<String, dynamic> metadata;
  String state;
  String? error;
  Map<String, dynamic>? photo;
  Map<String, dynamic> toJson() => {'id':id,'ownerId':ownerId,'asset':asset.toJson(),'metadata':metadata,'state':state,'error':error,'photo':photo};
  factory QueueEntry.fromJson(Map<String, dynamic> data) => QueueEntry(id:data['id'] as String,ownerId:data['ownerId'] as String,asset:LocalAsset.fromJson(data['asset'] as Map<String,dynamic>),metadata:data['metadata'] as Map<String,dynamic>,state:recoverState(data['state'] as String),error:data['error'] as String?,photo:data['photo'] as Map<String,dynamic>?);
  static String recoverState(String state) => state=='uploading' || state=='finalizing' ? 'queued' : state;
  Map<String, dynamic> publicView() => {'id':id,'state':state,'fileName':asset.fileName,if(error!=null)'error':error,if(photo!=null)'photo':photo};
}

class UploadQueue {
  UploadQueue(this.api, {Directory? directory}) : _directory=directory;
  final NativeApi api;
  Directory? _directory;
  final Map<String, LocalAsset> _assets={};
  final Map<String,String> _assetOwners={};
  final List<QueueEntry> _entries=[];
  bool _running=false;
  Future<void> _writes=Future.value();
  void Function()? onChanged;
  Future<Directory> get directory async => _directory ??= Directory('${(await getApplicationSupportDirectory()).path}/hangyeol_uploads');
  Future<void> initialize() async {
    final root=await directory; await root.create(recursive:true);
    final file=File('${root.path}/queue.json');
    final backup=File('${root.path}/queue.json.bak');
    if (!await file.exists() && await backup.exists()) { await backup.copy(file.path); }
    if (!await file.exists()) { return; }
    final data=jsonDecode(await file.readAsString()) as Map<String,dynamic>;
    _entries.addAll((data['entries'] as List).map((e)=>QueueEntry.fromJson(e as Map<String,dynamic>)));
    for(final record in data['assets'] as List? ?? []) {
      final asset=LocalAsset.fromJson(record['asset'] as Map<String,dynamic>);
      _assets[asset.handle]=asset;_assetOwners[asset.handle]=record['ownerId'] as String;
    }
    for(final entry in _entries) { if(entry.state!='complete'){ _assets[entry.asset.handle]=entry.asset;_assetOwners[entry.asset.handle]=entry.ownerId; } }
  }
  Future<void> _save() {
    _writes=_writes.catchError((Object _) {}).then((_) async {
      final root=await directory;await root.create(recursive:true);
      final file=File('${root.path}/queue.json'),temp=File('${root.path}/queue.json.tmp'),backup=File('${root.path}/queue.json.bak');
      await temp.writeAsString(jsonEncode({'entries':_entries.map((e)=>e.toJson()).toList(),'assets':_assets.values.map((a)=>{'asset':a.toJson(),'ownerId':_assetOwners[a.handle]}).toList()}),flush:true);
      if(await backup.exists()){ await backup.delete(); }
      if(await file.exists()){ await file.rename(backup.path); }
      await temp.rename(file.path);
    });
    return _writes;
  }
  Future<LocalAsset> importFile(String path, {String? name, bool newlyCaptured=false,String? ownerId}) async {
    final owner=ownerId??api.userId;
    if(owner==null||owner!=api.userId){ throw ApiFailure('로그인한 계정이 변경되었습니다.',code:'AUTH_REQUIRED'); }
    final source=File(path);
    final fileName=(name??source.uri.pathSegments.last).replaceAll(RegExp(r'[/\\]'),'_');
    final extension=fileName.split('.').last.toLowerCase();
    final mime={'jpg':'image/jpeg','jpeg':'image/jpeg','png':'image/png','webp':'image/webp'}[extension];
    if(mime==null){ throw ApiFailure('JPG, PNG, WebP 사진을 선택해 주세요.',code:'UNSUPPORTED_TYPE'); }
    final size=await source.length();
    if(size>20*1024*1024){ throw ApiFailure('사진은 한 장당 20MB까지 등록할 수 있습니다.',code:'FILE_TOO_LARGE'); }
    final handle=const Uuid().v4();final root=await directory;await root.create(recursive:true);
    final destination=await source.copy('${root.path}/$handle.$extension');
    final asset=LocalAsset(handle:handle,path:destination.path,fileName:fileName,contentType:mime,size:size,capturedAt:newlyCaptured?DateTime.now().toUtc().toIso8601String():null);
    _assets[handle]=asset;_assetOwners[handle]=owner;await _save();return asset;
  }
  Future<QueueEntry> enqueue(String handle, Map<String,dynamic> metadata) async {
    if(api.userId==null){ throw ApiFailure('앱에서 먼저 로그인해 주세요.',code:'AUTH_REQUIRED'); }
    final asset=_assets[handle];if(asset==null||_assetOwners[handle]!=api.userId){ throw ApiFailure('선택한 사진을 다시 불러와 주세요.',code:'ASSET_NOT_FOUND'); }
    final previous=_entries.where((e)=>e.asset.handle==handle&&e.ownerId==api.userId);
    if(previous.isNotEmpty){ return previous.first; }
    final entry=QueueEntry(id:const Uuid().v4(),ownerId:api.userId!,asset:asset,metadata:Map<String,dynamic>.from(metadata));
    _entries.add(entry);await _save();onChanged?.call();return entry;
  }
  List<Map<String,dynamic>> status() => _entries.where((e)=>e.ownerId==api.userId).map((e)=>e.publicView()).toList();
  Future<void> retry({String? id}) async {
    if(_running||api.userId==null||api.token==null){ return; }
    _running=true;
    final sessionApi=api.snapshot(),owner=api.userId,token=api.token;
    bool current()=>api.userId==owner&&api.token==token;
    try {
      for(final entry in _entries.where((e)=>e.ownerId==owner&&e.state!='complete'&&(id==null||e.id==id)).toList()) {
        if(!current()){ break; }
        try {
          entry.state='uploading';entry.error=null;await _save();onChanged?.call();
          final session=await sessionApi.request('/v1/upload-sessions',method:'POST',body:{'clientRequestId':entry.id,'fileName':entry.asset.fileName,'contentType':entry.asset.contentType,'size':entry.asset.size,'metadata':entry.metadata});
          if(!current()){entry.state='queued';await _save();break;}
          if(session['status']=='complete') {
            entry.photo=session['photo'] as Map<String,dynamic>?;
          } else {
            if(session['status']!='uploaded'){ await sessionApi.upload(session['uploadUrl'] as String,await File(entry.asset.path).readAsBytes(),entry.asset.contentType); }
            if(!current()){entry.state='queued';await _save();break;}
            entry.state='finalizing';await _save();onChanged?.call();
            final complete=await sessionApi.request('/v1/upload-sessions/${session['id']}/complete',method:'POST',body:{});
            entry.photo=complete['photo'] as Map<String,dynamic>;
          }
          entry.state='complete';await _save();
          final file=File(entry.asset.path);if(await file.exists()){ await file.delete(); }
          _assets.remove(entry.asset.handle);_assetOwners.remove(entry.asset.handle);
        } catch(error) {entry.state='failed';entry.error=error is ApiFailure?error.message:'연결을 확인한 뒤 다시 시도해 주세요.';await _save();}
        onChanged?.call();
      }
    } finally {_running=false;}
  }
  void clearUnqueuedAssets() {
    final queued=_entries.map((e)=>e.asset.handle).toSet();
    for(final key in _assets.keys.toList()) {
      if(!queued.contains(key)){File(_assets[key]!.path).delete().catchError((Object _)=>File(''));_assets.remove(key);_assetOwners.remove(key);}
    }
    _save();
  }
}
