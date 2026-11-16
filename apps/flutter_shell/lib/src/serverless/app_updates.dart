import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'client.dart';

enum UpdatePlatform { android,windows }
UpdatePlatform? updatePlatform()=>kIsWeb?null:switch(defaultTargetPlatform){TargetPlatform.android=>UpdatePlatform.android,TargetPlatform.windows=>UpdatePlatform.windows,_=>null};
class InstalledAppBuild {
  const InstalledAppBuild({this.version=const String.fromEnvironment('APP_VERSION',defaultValue:'0.2.0'),this.build=const int.fromEnvironment('APP_BUILD_NUMBER',defaultValue:0)});
  final String version;
  final int build;
}
class AppUpdateRelease {
  AppUpdateRelease._({required this.version,required this.build,required this.bytes,required this.download,required this.page,required this.publishedAt,required this.notes,required this.isDrive});
  final String version,notes;
  final int build,bytes;
  final Uri download,page;
  final DateTime publishedAt;
  final bool isDrive;
  factory AppUpdateRelease.parse(Map<String,dynamic> value,UpdatePlatform platform){
    final version=value['version'],build=value['build'],bytes=value['bytes'];
    final download=Uri.tryParse(value['downloadUrl'] as String? ?? ''),page=Uri.tryParse(value['releaseUrl'] as String? ?? '');
    final date=DateTime.tryParse(value['publishedAt'] as String? ?? ''),notes=value['notes'];
    final expected=platform==UpdatePlatform.android?'hangyeol-online.apk':'hangyeol-online-windows.zip';
    final segments=download?.pathSegments??[];
    bool official(Uri? uri)=>uri!=null&&uri.scheme=='https'&&uri.host=='github.com'&&uri.port==443&&uri.userInfo.isEmpty&&!uri.hasQuery&&!uri.hasFragment;
    if(value['platform']!=platform.name||version is! String||!RegExp(r'^\d{1,4}\.\d{1,4}\.\d{1,4}$').hasMatch(version)||build is! int||build<1||build>2100000000||bytes is! int||bytes<1||bytes>300*1024*1024||!official(download)||!official(page)||segments.length!=6||segments.take(4).join('/')!='OKHand/Hangyeol/releases/download'||!RegExp(r'^[A-Za-z0-9._-]{1,120}$').hasMatch(segments[4])||segments[5]!=expected||page!.toString()!='https://github.com/OKHand/Hangyeol/releases/tag/${segments[4]}'||date==null||notes is! String||notes.length>1600||!RegExp(r'^[a-f0-9]{64}$').hasMatch(value['sha256'] as String? ?? '')){
      throw PlatformAuthFailure('INVALID_UPDATE','기기에 맞는 공식 업데이트 정보를 확인하지 못했습니다.');
    }
    Uri selectedDownload=download!,selectedPage=page;var isDrive=false;
    if(value['driveFileId']!=null||value['driveFolderId']!=null||value['driveDownloadUrl']!=null||value['drivePageUrl']!=null){
      final id=value['driveFileId'],folder=value['driveFolderId'];
      if(id is! String||!RegExp(r'^[A-Za-z0-9_-]{10,200}$').hasMatch(id)||folder is! String||!RegExp(r'^[A-Za-z0-9_-]{10,200}$').hasMatch(folder)||id==folder||value['driveDownloadUrl']!='https://drive.google.com/uc?export=download&id=$id'||value['drivePageUrl']!='https://drive.google.com/file/d/$id/view'){
        throw PlatformAuthFailure('INVALID_UPDATE','Drive 설치 파일 정보를 확인하지 못했습니다.');
      }
      selectedDownload=Uri.parse(value['driveDownloadUrl'] as String);selectedPage=Uri.parse(value['drivePageUrl'] as String);isDrive=true;
    }
    return AppUpdateRelease._(version:version,build:build,bytes:bytes,download:selectedDownload,page:selectedPage,publishedAt:date,notes:notes,isDrive:isDrive);
  }
  bool newerThan(InstalledAppBuild installed){
    if(build<=installed.build){return false;}
    final before=installed.version.split('.').map(int.tryParse).toList(),after=version.split('.').map(int.parse).toList();
    if(before.length!=3||before.contains(null)){return false;}
    for(var i=0;i<3;i++){if(after[i]<before[i]!){return false;}if(after[i]>before[i]!){return true;}}
    return true;
  }
}
class AppUpdatePage extends StatefulWidget {
  const AppUpdatePage({super.key,required this.client,required this.onAuthError,this.platform,this.installed=const InstalledAppBuild(),this.launch,this.googleEmail});
  final AppsScriptPlatformClient client;
  final Future<void> Function(Object) onAuthError;
  final UpdatePlatform? platform;
  final InstalledAppBuild installed;
  final Future<bool> Function(Uri)? launch;
  final String? googleEmail;
  @override
  State<AppUpdatePage> createState()=>_AppUpdatePageState();
}
class _AppUpdatePageState extends State<AppUpdatePage> {
  late final UpdatePlatform? _platform=widget.platform??updatePlatform();
  AppUpdateRelease? _release;
  bool _busy=false,_opening=false,_checked=false;
  String _error='';
  @override
  void initState(){super.initState();if(_platform!=null){_check();}}
  Future<void> _check() async {
    if(_busy||_platform==null){return;}
    setState((){_busy=true;_error='';_release=null;});
    try{
      final value=await widget.client.call('updates.check',params:{'platform':_platform.name});
      final release=value['release'];
      final parsed=release==null?null:AppUpdateRelease.parse(Map<String,dynamic>.from(release as Map),_platform);
      if(mounted){setState((){_release=parsed;_checked=true;});}
    }catch(error){
      if(error is PlatformAuthFailure&&const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(error.code)){await widget.onAuthError(error);}
      if(mounted){setState(()=>_error=error is PlatformAuthFailure?error.message:'업데이트를 확인하지 못했습니다. 다시 시도해 주세요.');}
    }finally{if(mounted){setState(()=>_busy=false);}}
  }
  Future<void> _open(Uri uri) async {
    if(_opening){return;}
    setState((){_opening=true;_error='';});
    final email=widget.googleEmail;
    final target=_release?.isDrive==true&&email!=null&&email.contains('@')?uri.replace(queryParameters:{...uri.queryParameters,'authuser':email}):uri;
    try{if(!await (widget.launch?.call(target)??launchUrl(target,mode:LaunchMode.externalApplication))){throw StateError('Browser unavailable');}}
    catch(_){if(mounted){setState(()=>_error='다운로드 브라우저를 열지 못했습니다. 다시 시도하거나 다운로드 페이지를 열어 주세요.');}}
    finally{if(mounted){setState(()=>_opening=false);}}
  }
  String _day(DateTime date){final local=date.toLocal();return '${local.year}-${local.month.toString().padLeft(2,'0')}-${local.day.toString().padLeft(2,'0')}';}
  @override
  Widget build(BuildContext context){
    final release=_release,android=_platform==UpdatePlatform.android;
    final newer=release?.newerThan(widget.installed)??false;
    return Scaffold(appBar:AppBar(title:const Text('앱 업데이트')),body:SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[
      const Icon(Icons.system_update_outlined,size:48),const SizedBox(height:16),
      Text(_platform==null?'앱 업데이트':android?'Android 앱 업데이트':'Windows 앱 업데이트',style:Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:12),Text('현재 버전 ${widget.installed.version}${widget.installed.build>0?' · 빌드 ${widget.installed.build}':' · 개발 버전'}'),
      if(_platform==null)const Padding(padding:EdgeInsets.symmetric(vertical:16),child:Text('업데이트 파일은 Android와 Windows 앱에서 받을 수 있습니다.')),
      if(_busy)const Padding(padding:EdgeInsets.symmetric(vertical:16),child:LinearProgressIndicator()),
      if(_error.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Text(_error,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      if(release!=null)...[
        const SizedBox(height:20),Text(newer?'새 버전이 있습니다.':release.build==widget.installed.build&&release.version==widget.installed.version?'현재 최신 버전입니다.':'설치된 앱보다 새로운 업데이트가 없습니다.',key:const Key('update-status'),style:const TextStyle(fontWeight:FontWeight.bold)),
        Text('게시 버전 ${release.version} · 빌드 ${release.build}\n${_day(release.publishedAt)} · ${(release.bytes/1024/1024).toStringAsFixed(1)} MB'),
        if(release.notes.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Text(release.notes)),
        if(newer||release.build==widget.installed.build&&release.version==widget.installed.version)...[
          FilledButton.icon(key:const Key('update-download'),onPressed:_opening?null:()=>_open(release.download),icon:const Icon(Icons.download_outlined),label:Text(android?'Android APK 다운로드':'Windows ZIP 다운로드')),
          const SizedBox(height:12),Text(release.isDrive?'Google Drive에서 다운로드합니다. 앱에서 사용하는 회사 Google 계정으로 로그인해 주세요.':'브라우저에서 다운로드합니다. 비공개 GitHub 저장소에 로그인해야 파일을 받을 수 있습니다.'),
          const SizedBox(height:12),Text(android?'다운로드한 APK를 열고 업데이트를 확인하세요. 기존 앱을 삭제할 필요는 없습니다.':'ZIP을 모두 압축 해제한 뒤 앱을 종료하고 새 폴더의 HangyeolOnline/hangyeol_online.exe를 실행하세요. 실행 파일과 함께 있는 DLL·data 폴더도 유지하세요.'),
          TextButton(key:const Key('update-release-page'),onPressed:_opening?null:()=>_open(release.page),child:Text(release.isDrive?'Drive에서 파일 보기':'다운로드 페이지 열기')),
        ],
      ]else if(_checked&&!_busy&&_error.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:20),child:Text('이 기기에 등록된 업데이트가 아직 없습니다.')),
      if(_platform!=null)OutlinedButton.icon(key:const Key('update-check'),onPressed:_busy?null:_check,icon:const Icon(Icons.refresh),label:const Text('업데이트 다시 확인')),
    ])));
  }
}
