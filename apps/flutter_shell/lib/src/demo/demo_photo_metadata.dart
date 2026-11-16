import 'dart:io';
import 'package:exif/exif.dart';
import 'demo_erp.dart';
class DemoPhotoMetadata {
  const DemoPhotoMetadata({this.date='',this.time='',this.dateSource='unknown',this.latitude,this.longitude,this.locationSource='unknown'});
  final String date,time,dateSource,locationSource;
  final double? latitude,longitude;
  static DemoPhotoMetadata parse(Map<String,String> tags) {
    final raw=tags['EXIF DateTimeOriginal']??'';
    final match=RegExp(r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})').firstMatch(raw);
    var date='',time='';
    if (match!=null&&int.parse(match[4]!)<24&&int.parse(match[5]!)<60&&int.parse(match[6]!)<60) {
      final parsed=DateTime.tryParse('${match[1]}-${match[2]}-${match[3]}T${match[4]}:${match[5]}:${match[6]}');
      if (parsed!=null&&parsed.year==int.parse(match[1]!)&&parsed.month==int.parse(match[2]!)&&parsed.day==int.parse(match[3]!)) { date=demoDay(parsed);time='${match[4]}:${match[5]}'; }
    }
    double? coordinate(String? value,String? ref,int max) {
      if (value==null||ref==null||!(max==90?['N','S']:['E','W']).contains(ref.trim().toUpperCase())) { return null; }
      final pieces=RegExp(r'-?\d+(?:\.\d+)?(?:/\d+)?').allMatches(value).map((m) { final parts=m[0]!.split('/');return parts.length==1?double.parse(parts[0]):double.parse(parts[0])/double.parse(parts[1]); }).toList();
      if (pieces.length!=3) { return null; }
      final n=pieces[0]+pieces[1]/60+pieces[2]/3600;
      if (!n.isFinite||n>max||n<0) { return null; }
      return ['S','W'].contains(ref.trim().toUpperCase())?-n:n;
    }
    final lat=coordinate(tags['GPS GPSLatitude'],tags['GPS GPSLatitudeRef'],90),lon=coordinate(tags['GPS GPSLongitude'],tags['GPS GPSLongitudeRef'],180);
    return DemoPhotoMetadata(date:date,time:time,dateSource:date.isEmpty?'unknown':'exif',latitude:lat!=null&&lon!=null?lat:null,longitude:lat!=null&&lon!=null?lon:null,locationSource:lat!=null&&lon!=null?'exif':'unknown');
  }
  static Future<DemoPhotoMetadata> read(File file,{bool camera=false}) async {
    try {
      if (await file.length()<40*1024*1024) {
        final tags=await readExifFromBytes(await file.readAsBytes());
        final result=parse(tags.map((k,v)=>MapEntry(k,v.printable)));
        if (result.date.isNotEmpty||!camera) { return result; }
      }
    } catch (_) { /* Unknown is retained rather than guessing an old photo's date. */ }
    if (camera) { final now=DateTime.now();return DemoPhotoMetadata(date:demoDay(now),time:'${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',dateSource:'device'); }
    return const DemoPhotoMetadata();
  }
}
