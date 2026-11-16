import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
export 'demo_erp.dart';

class DemoPhoto {
  const DemoPhoto({required this.id, required this.fileName, required this.title, required this.variety, required this.location, required this.note, required this.date, this.farmName = '', this.crop = '', this.createdAt = '', this.time = '', this.dateSource = 'unknown', this.latitude, this.longitude, this.locationSource = 'unknown'});
  final String id, fileName, title, variety, location, note, date, farmName, crop, createdAt, time, dateSource, locationSource;
  final double? latitude, longitude;
  bool get needsInfo => farmName.trim().isEmpty || crop.trim().isEmpty || date.trim().isEmpty;
  bool get isSample => const {'sample-tomato','sample-pepper','sample-cucumber'}.contains(fileName);
  String get number => 'PHOTO-${id.replaceAll('-', '').substring(0, id.length < 8 ? id.length : 8).toUpperCase()}';
  Map<String, Object?> toJson() => {'id':id,'fileName':fileName,'title':title,'variety':variety,'location':location,'note':note,'date':date,'farmName':farmName,'crop':crop,'createdAt':createdAt,'time':time,'dateSource':dateSource,'latitude':latitude,'longitude':longitude,'locationSource':locationSource};
  factory DemoPhoto.fromJson(Map<String, dynamic> value) {
    final fileName = value['fileName'] as String;
    if (!RegExp(r'^[a-f0-9-]+\.(jpg|png|webp|heic|jpeg)$').hasMatch(fileName) && !const {'sample-tomato','sample-pepper','sample-cucumber'}.contains(fileName)) { throw const FormatException('Invalid demo photo filename'); }
    return DemoPhoto(id:value['id'] as String,fileName:fileName,title:value['title'] as String,variety:value['variety'] as String,location:value['location'] as String,note:value['note'] as String,date:value['date'] as String,farmName:value['farmName'] as String? ?? '',crop:value['crop'] as String? ?? '',createdAt:value['createdAt'] as String? ?? '',time:value['time'] as String? ?? '',dateSource:value['dateSource'] as String? ?? (value['date']==''?'unknown':'manual'),latitude:(value['latitude'] as num?)?.toDouble(),longitude:(value['longitude'] as num?)?.toDouble(),locationSource:value['locationSource'] as String? ?? 'unknown');
  }
}
const demoSamplePhotos = [
  DemoPhoto(id:'sample01',fileName:'sample-tomato',title:'첫 착과 관찰',farmName:'한결 체험농장',crop:'토마토',variety:'체험 루비',location:'전남 담양군 체험 시험포 1동',note:'1화방 착과를 확인했습니다. 초세와 과형을 다음 기록과 비교해 보세요.',date:'2026-11-03',time:'09:30',dateSource:'manual',createdAt:'2026-11-04T01:00:00Z'),
  DemoPhoto(id:'sample02',fileName:'sample-pepper',title:'고추 생육 조사',farmName:'가명C 체험농장',crop:'고추',variety:'체험 햇살',location:'강원 춘천시 체험 하우스',note:'절간과 잎 색을 관찰한 체험 기록입니다.',date:'2026-11-05',time:'14:20',dateSource:'manual',createdAt:'2026-11-05T06:00:00Z'),
  DemoPhoto(id:'sample03',fileName:'sample-cucumber',title:'농가 정보 보완 대기',farmName:'',crop:'오이',variety:'체험 초록',location:'경남 김해시 체험 시험포',note:'정보 수정을 눌러 농가명과 촬영일을 입력해 보세요. 촬영일을 모르면 비워 두고 보완 필요로 보관합니다.',date:'',createdAt:'2026-11-06T03:00:00Z'),
];
class DemoPhotoFilter {
  const DemoPhotoFilter({this.farm='',this.crop='',this.region='',this.query='',this.status='',this.dateBasis='captured',this.start,this.end});
  final String farm,crop,region,query,status,dateBasis;
  final DateTime? start,end;
  bool matches(DemoPhoto r) {
    bool contains(String value,String q) => value.replaceAll(' ','').toLowerCase().contains(q.replaceAll(' ','').toLowerCase());
    if (!contains(r.farmName,farm)||!contains(r.crop,crop)||!contains(r.location,region)||!contains('${r.title} ${r.variety} ${r.note}',query)) { return false; }
    if (status=='needs_info'&&!r.needsInfo||status=='ready'&&r.needsInfo) { return false; }
    if (start!=null||end!=null) {
      final raw=dateBasis=='created'?r.createdAt:r.date;
      final date=DateTime.tryParse(raw);
      if (date==null) { return false; }
      final korean=date.toUtc().add(const Duration(hours:9));
      final day=dateBasis=='created'?DateTime(korean.year,korean.month,korean.day):DateTime(date.year,date.month,date.day);
      if (start!=null&&day.isBefore(start!)||end!=null&&day.isAfter(end!)) { return false; }
    }
    return true;
  }
}
class DemoStore {
  DemoStore(this.directory,{this.seedSamples=true});
  final Directory directory;
  final bool seedSamples;
  List<DemoPhoto> _photos=[];
  List<Map<String,dynamic>> _jobs=[];
  List<DemoPhoto> get photos=>List.unmodifiable(_photos);
  List<Map<String,dynamic>> get jobs=>List.unmodifiable(_jobs);
  static Future<DemoStore> open() async {
    final base=await getApplicationDocumentsDirectory();
    final store=DemoStore(Directory('${base.path}/offline-demo-v1'));
    await store.load(); return store;
  }
  File photoFile(DemoPhoto photo)=>File('${directory.path}/${photo.fileName}');
  File get _index=>File('${directory.path}/photos.json');
  Future<void> load() async {
    await directory.create(recursive:true);
    if (await _index.exists()) {
      final data=jsonDecode(await _index.readAsString()) as List;
      _photos=data.map((r)=>DemoPhoto.fromJson(Map<String,dynamic>.from(r as Map))).toList();
    } else if (seedSamples) { await _save(demoSamplePhotos); }
    final jobs=File('${directory.path}/demo-jobs.json');
    if (await jobs.exists()) { _jobs=(jsonDecode(await jobs.readAsString()) as List).map((r)=>Map<String,dynamic>.from(r as Map)).toList(); }
  }
  Future<void> _save(List<DemoPhoto> next) async {
    final pending=File('${_index.path}.pending');
    await pending.writeAsString(jsonEncode(next.map((r)=>r.toJson()).toList()),flush:true);
    await pending.rename(_index.path); _photos=List.of(next);
  }
  Future<void> add({required File source,required String title,required String variety,required String location,required String note,required String date,String farmName='',String crop='',String time='',String dateSource='unknown',double? latitude,double? longitude,String locationSource='unknown'}) async {
    final id=const Uuid().v4();
    var extension=source.path.split('.').last.toLowerCase();
    if (!['jpg','jpeg','png','webp','heic'].contains(extension)) { extension='jpg'; }
    final photo=DemoPhoto(id:id,fileName:'$id.$extension',title:title.trim(),variety:variety.trim(),location:location.trim(),note:note.trim(),date:date,farmName:farmName.trim(),crop:crop.trim(),time:time,dateSource:dateSource,latitude:latitude,longitude:longitude,locationSource:locationSource,createdAt:DateTime.now().toUtc().toIso8601String());
    final dest=photoFile(photo); await source.copy(dest.path);
    try { await _save([photo,..._photos]); } catch (_) { await dest.delete(); rethrow; }
  }
  Future<void> update(DemoPhoto photo) async {
    if (!_photos.any((r)=>r.id==photo.id)) { throw StateError('Photo no longer exists'); }
    await _save(_photos.map((r)=>r.id==photo.id?photo:r).toList());
  }
  Future<void> remove(DemoPhoto photo) async {
    await _save(_photos.where((r)=>r.id!=photo.id).toList());
    if (!photo.isSample) { final file=photoFile(photo); if (await file.exists()) { await file.delete(); } }
  }
  Future<void> reset({bool restoreSamples=false}) async {
    final old=List<DemoPhoto>.of(_photos);
    await _save(restoreSamples?demoSamplePhotos:[]);
    for (final photo in old.where((p)=>!p.isSample)) { final file=photoFile(photo); if (await file.exists()) { await file.delete(); } }
    _jobs=[]; await File('${directory.path}/demo-jobs.json').writeAsString('[]',flush:true);
  }
  Future<void> simulateIntegrations(DemoPhoto photo) async {
    final next=[...['sheets','discord'].map((type)=><String,dynamic>{'photoId':photo.id,'title':photo.title,'type':type,'createdAt':DateTime.now().toUtc().toIso8601String(),'status':'demo','message':'미리보기 기록 생성 · 외부 전송 없음'}),..._jobs].take(50).toList();
    final pending=File('${directory.path}/demo-jobs.json.pending');
    await pending.writeAsString(jsonEncode(next),flush:true); await pending.rename('${directory.path}/demo-jobs.json'); _jobs=next;
  }
}
