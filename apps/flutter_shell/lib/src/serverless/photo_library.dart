import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'client.dart';
import 'photo_repository.dart';

/// Admin-only catalogue. Authorization is also enforced by every server route.
class PhotoLibraryPage extends StatefulWidget {
  const PhotoLibraryPage({super.key,required this.client,required this.repository,required this.onAuthError,required this.openPhoto});
  final AppsScriptPlatformClient client;
  final PhotoRepository repository;
  final Future<void> Function(Object) onAuthError;
  final Future<void> Function(Map<String,dynamic>) openPhoto;
  @override
  State<PhotoLibraryPage> createState()=>_PhotoLibraryPageState();
}

class _PhotoLibraryPageState extends State<PhotoLibraryPage> {
  List<Map<String,dynamic>> _farms=[],_photos=[],_jobs=[];
  Map<String,dynamic> _settings={},_counts={};
  final _selected=<String,Map<String,dynamic>>{};
  bool _busy=false,_needsReview=true;
  int _tab=0,_total=0;
  int? _next,_nextJobs;
  String _error='',_notice='',_farmId='',_visitId='',_collection='';
  @override
  void initState(){super.initState();_reload();}
  Future<void> _fail(Object error) async {
    if(error is PlatformAuthFailure&&const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(error.code)){await widget.onAuthError(error);}
    if(mounted){setState(()=>_error=error is PlatformAuthFailure?error.message:'처리하지 못했습니다. 새로고침한 뒤 다시 시도해 주세요.');}
  }
  Future<void> _work(Future<void> Function() action) async {
    if(_busy){return;}setState((){_busy=true;_error='';_notice='';});
    try{await action();}catch(e){await _fail(e);}finally{if(mounted){setState(()=>_busy=false);}}
  }
  Future<void> _reload()=>_work(() async {
    final library=await widget.client.call('photos.library');
    final jobs=await widget.client.call('discord.jobs');
    if(!mounted){return;}
    setState((){_farms=_records(library['farms']);_setJobs(jobs);_selected.clear();});
    await _loadPhotos();
  });
  List<Map<String,dynamic>> _records(dynamic value)=>List<Map<String,dynamic>>.from(value as List? ?? []);
  void _setJobs(Map<String,dynamic> data,{bool more=false}){
    _jobs=[if(more)..._jobs,..._records(data['jobs'])];_nextJobs=data['nextOffset'] as int?;
    _counts=Map<String,dynamic>.from(data['counts'] as Map? ?? {});_settings=Map<String,dynamic>.from(data['settings'] as Map? ?? {});
  }
  Future<void> _loadPhotos({bool more=false}) async {
    final result=await widget.client.call('photos.list',params:{'refresh':true,'offset':more?_next??0:0,
      if(_needsReview)'review':'needs_review',if(_farmId.isNotEmpty)'farmId':_farmId,if(_visitId.isNotEmpty)'visitId':_visitId});
    if(!mounted){return;}
    setState((){_photos={for(final p in [if(more)..._photos,..._records(result['photos'])])p['id'] as String:p}.values.toList();_total=result['total'] as int? ?? 0;_next=result['nextOffset'] as int?;});
  }
  Future<void> _collect()=>_work(() async {
    final result=await widget.client.call('discord.sync');if(!mounted){return;}
    setState((){_setJobs(result);_notice=result['discoveryError'] as String? ?? '';if(_notice.isEmpty){_notice='수집 상태를 갱신했습니다. 대기 중인 사진은 계속 수집을 눌러 주세요.';}});
    await _loadPhotos();
  });
  Future<void> _create(String kind) async {
    final result=await Navigator.of(context).push<bool>(MaterialPageRoute(builder:(_)=>_LibraryCreatePage(client:widget.client,kind:kind,farms:_farms,onAuthError:widget.onAuthError)));
    if(result==true&&mounted){await _reload();}
  }
  Future<void> _classify() async {
    final result=await Navigator.of(context).push<bool>(MaterialPageRoute(builder:(_)=>_ClassifyPage(client:widget.client,photos:_selected.values.toList(),farms:_farms,onAuthError:widget.onAuthError)));
    if(result==true&&mounted){await _reload();}
  }
  Future<void> _connect() async {
    final result=await Navigator.of(context).push<bool>(MaterialPageRoute(builder:(_)=>_DiscordConnectPage(client:widget.client,settings:_settings,onAuthError:widget.onAuthError)));
    if(result==true&&mounted){await _reload();}
  }
  void _toggle(Map<String,dynamic> photo){
    final id=photo['id'] as String;
    if(!_selected.containsKey(id)&&_selected.length>=100){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('한 번에 최대 100장까지 선택해 주세요.')));return;}
    setState((){if(_selected.containsKey(id)){_selected.remove(id);}else{_selected[id]=photo;}});
  }
  Future<void> _collectionPhotos(String farm,String visit,String label) async {
    setState((){_tab=0;_farmId=farm;_visitId=visit;_collection=label;_needsReview=false;_selected.clear();});
    await _work(_loadPhotos);
  }
  Widget _inbox()=>Column(children:[
    Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Row(children:[
      Expanded(child:DropdownButton<String>(key:const Key('library-review-filter'),value:_needsReview?'needs_review':'all',isExpanded:true,
        items:const [DropdownMenuItem(value:'needs_review',child:Text('정보 보완 필요')),DropdownMenuItem(value:'all',child:Text('전체 사진 정리'))],
        onChanged:_busy?null:(v){setState((){_needsReview=v=='needs_review';_selected.clear();});_work(_loadPhotos);})),
      Text('$_total장'),
    ])),
    if(_collection.isNotEmpty)Align(alignment:Alignment.centerLeft,child:InputChip(label:Text(_collection),onDeleted:_busy?null:(){setState((){_farmId='';_visitId='';_collection='';_selected.clear();});_work(_loadPhotos);})),
    Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Row(children:[Expanded(child:Text('선택 ${_selected.length}/100장')),
      TextButton(onPressed:_busy?null:(){for(final p in _photos.where((p)=>p['notification']!='sending')){if(_selected.length>=100){break;}_selected[p['id'] as String]=p;}setState((){});},child:const Text('목록 선택')),
      FilledButton.icon(key:const Key('library-classify'),onPressed:_busy||_selected.isEmpty||_farms.isEmpty?null:_classify,icon:const Icon(Icons.edit_outlined,size:18),label:const Text('분류')),
    ])),
    const Padding(padding:EdgeInsets.all(12),child:Text('선택한 사진에 농가·작물·방문을 연결합니다. 촬영일 미상은 그대로 유지합니다.',style:TextStyle(fontSize:12))),
    if(_farms.isEmpty)TextButton(onPressed:_busy?null:()=>_create('farm'),child:const Text('먼저 농가 등록')),
    Expanded(child:ListView.builder(itemCount:_photos.length+1,itemBuilder:(context,i){
      if(i==_photos.length){return _next!=null?TextButton(onPressed:_busy?null:()=>_work(()=>_loadPhotos(more:true)),child:const Text('더 보기')):_photos.isEmpty?const Padding(padding:EdgeInsets.all(24),child:Text('조건에 맞는 사진이 없습니다.')):const SizedBox(height:16);}
      final p=_photos[i];return ListTile(key:ValueKey('library-photo-${p['id']}'),dense:true,contentPadding:const EdgeInsets.symmetric(horizontal:8),
        leading:Checkbox(key:ValueKey('library-select-${p['id']}'),value:_selected.containsKey(p['id']),onChanged:_busy||p['notification']=='sending'?null:(_)=>_toggle(p)),
        title:Row(children:[SizedBox(width:48,height:48,child:_LibraryThumb(repository:widget.repository,photo:p)),const SizedBox(width:8),
          Expanded(child:Text('${(p['farm'] as String? ?? '').isEmpty?'농가 미입력':p['farm']} · ${(p['crop'] as String? ?? '').isEmpty?'작물 미입력':p['crop']}',maxLines:2,overflow:TextOverflow.ellipsis))]),
        subtitle:Text('${p['date']==''?'촬영일 미상':p['date']} · ${p['source']=='discord'?'Discord 수집':'앱 등록'}',style:const TextStyle(fontSize:11)),
        trailing:IconButton(tooltip:'사진 상세',onPressed:_busy?null:() async {await widget.openPhoto(p);if(mounted){await _reload();}},icon:const Icon(Icons.open_in_full,size:18)));
    })),
  ]);
  Widget _farmList()=>ListView(padding:const EdgeInsets.all(12),children:[
    Wrap(spacing:8,children:[FilledButton.icon(onPressed:_busy?null:()=>_create('farm'),icon:const Icon(Icons.add),label:const Text('농가 등록')),
      OutlinedButton.icon(onPressed:_busy||_farms.isEmpty?null:()=>_create('visit'),icon:const Icon(Icons.event_outlined),label:const Text('방문 등록'))]),
    const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('방문일은 촬영일과 별개입니다. 농가나 방문을 눌러 연결된 사진을 확인하세요.')),
    for(final farm in _farms)ExpansionTile(title:Text(farm['name'] as String),subtitle:Text(farm['region'] as String? ?? ''),children:[
      ListTile(dense:true,title:const Text('이 농가의 모든 사진'),trailing:const Icon(Icons.chevron_right),onTap:()=>_collectionPhotos(farm['id'] as String,'',farm['name'] as String)),
      // Fetch a farm's visits when expanded so a global catalogue page cannot
      // silently hide older visits belonging to this farm.
      _FarmVisits(key:ValueKey(farm['id']),client:widget.client,farm:farm,onAuthError:widget.onAuthError,onOpen:_collectionPhotos),
    ]),
  ]);
  Widget _discord()=>ListView(padding:const EdgeInsets.all(12),children:[
    ListTile(contentPadding:EdgeInsets.zero,title:Text(_settings['configured']==true?'연결 채널 · ${_settings['channelName']}':'Discord 수집 미연결'),
      subtitle:const Text('새 메시지의 사진 첨부만 수동 수집합니다.'),trailing:IconButton(tooltip:'Discord 수집 설정',onPressed:_busy?null:_connect,icon:const Icon(Icons.settings_outlined))),
    const Text('같은 파일은 기존 사진에 출처만 연결합니다. 농가·촬영일은 자동 추정하지 않습니다.',style:TextStyle(fontSize:12)),
    Padding(padding:const EdgeInsets.symmetric(vertical:12),child:FilledButton.icon(key:const Key('discord-import-sync'),onPressed:_busy||_settings['configured']!=true?null:_collect,icon:const Icon(Icons.sync),label:const Text('새 사진 수집 / 계속 수집'))),
    Text('대기 ${_counts['pending']??0} · 저장 ${_counts['stored']??0} · 실패 ${_counts['failed']??0} · 원본 없음 ${_counts['unavailable']??0} · 미지원 ${_counts['unsupported']??0}'),
    if(_settings['continuation']==true)const Text('다음 메시지 페이지가 남아 있습니다. 계속 수집을 눌러 주세요.'),
    for(final job in _jobs)ListTile(dense:true,contentPadding:EdgeInsets.zero,
      title:Text(job['filename'] as String? ?? '사진',maxLines:1,overflow:TextOverflow.ellipsis),
      subtitle:Text('${job['duplicate']==true?'중복 파일 · 기존 사진 연결':const {'stored':'저장 완료','pending':'수집 대기','failed':'수집 실패','unavailable':'원본 없음','unsupported':'지원하지 않는 파일'}[job['state']]??job['state']}\n${job['error']??''}',style:const TextStyle(fontSize:11)),
      trailing:const {'failed','unavailable'}.contains(job['state'])?TextButton(onPressed:_busy||_settings['configured']!=true?null:()=>_work(() async {final result=await widget.client.call('discord.retry',params:{'id':job['id']});if(mounted){setState(()=>_setJobs(result));}}),child:const Text('재시도 대기')):null),
    if(_nextJobs!=null)TextButton(onPressed:_busy?null:()=>_work(() async {final result=await widget.client.call('discord.jobs',params:{'offset':_nextJobs});if(mounted){setState(()=>_setJobs(result,more:true));}}),child:const Text('기록 더 보기')),
  ]);
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('사진 정리'),actions:[IconButton(tooltip:'사진 정리 새로고침',onPressed:_busy?null:_reload,icon:const Icon(Icons.refresh))]),body:Column(children:[
    if(_busy)const LinearProgressIndicator(),
    if(_error.isNotEmpty)Padding(padding:const EdgeInsets.all(12),child:Text(_error,style:TextStyle(color:Theme.of(context).colorScheme.error))),
    if(_notice.isNotEmpty)Padding(padding:const EdgeInsets.all(12),child:Text(_notice)),
    Row(children:[for(final entry in const {0:'보완함',1:'농가·방문',2:'Discord 수집'}.entries)Expanded(child:TextButton(onPressed:_busy?null:()=>setState(()=>_tab=entry.key),child:Text(entry.value,style:TextStyle(fontWeight:_tab==entry.key?FontWeight.bold:FontWeight.normal))))]),
    Expanded(child:_tab==0?_inbox():_tab==1?_farmList():_discord()),
  ]));
}

class _LibraryThumb extends StatefulWidget {
  const _LibraryThumb({required this.repository,required this.photo});
  final PhotoRepository repository;final Map<String,dynamic> photo;
  @override
  State<_LibraryThumb> createState()=>_LibraryThumbState();
}
class _LibraryThumbState extends State<_LibraryThumb> {
  late final Future<Uint8List?> _bytes=widget.repository.thumbnail(widget.photo);
  @override
  Widget build(BuildContext context)=>FutureBuilder<Uint8List?>(future:_bytes,builder:(context,snapshot)=>snapshot.data==null?const Icon(Icons.photo_outlined):Image.memory(snapshot.data!,fit:BoxFit.cover,errorBuilder:(_,error,stack)=>const Icon(Icons.broken_image_outlined)));
}

class _FarmVisits extends StatefulWidget {
  const _FarmVisits({super.key,required this.client,required this.farm,required this.onAuthError,required this.onOpen});
  final AppsScriptPlatformClient client;final Map<String,dynamic> farm;
  final Future<void> Function(Object) onAuthError;
  final Future<void> Function(String,String,String) onOpen;
  @override
  State<_FarmVisits> createState()=>_FarmVisitsState();
}
class _FarmVisitsState extends State<_FarmVisits> {
  final _visits=<Map<String,dynamic>>[];bool _busy=false;int? _next=0;String _error='';
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    setState(()=>_busy=true);
    try{final result=await widget.client.call('photos.library',params:{'farmId':widget.farm['id'],'offset':_next});if(mounted){setState((){_visits.addAll(List<Map<String,dynamic>>.from(result['visits'] as List));_next=result['nextOffset'] as int?;_error='';});}}
    catch(e){await widget.onAuthError(e);if(mounted){setState(()=>_error=e is PlatformAuthFailure?e.message:'방문 목록을 불러오지 못했습니다.');}}
    finally{if(mounted){setState(()=>_busy=false);}}
  }
  @override
  Widget build(BuildContext context)=>Column(children:[
    for(final v in _visits)ListTile(dense:true,title:Text('${v['date']} · ${v['assignee']}'),subtitle:Text(v['note'] as String? ?? ''),onTap:()=>widget.onOpen(widget.farm['id'] as String,v['id'] as String,'${widget.farm['name']} · ${v['date']}')),
    if(_error.isNotEmpty)Text(_error),
    if(_next!=null)TextButton(onPressed:_busy?null:_load,child:Text(_busy?'불러오는 중':'방문 더 보기')),
  ]);
}

class _LibraryCreatePage extends StatefulWidget {
  const _LibraryCreatePage({required this.client,required this.kind,required this.farms,required this.onAuthError});
  final AppsScriptPlatformClient client;final String kind;final List<Map<String,dynamic>> farms;final Future<void> Function(Object) onAuthError;
  @override
  State<_LibraryCreatePage> createState()=>_LibraryCreatePageState();
}
class _LibraryCreatePageState extends State<_LibraryCreatePage> {
  final _form=GlobalKey<FormState>();final _operation=const Uuid().v4();final _name=TextEditingController(),_region=TextEditingController(),_note=TextEditingController(),_date=TextEditingController(),_assignee=TextEditingController();
  String? _farm;String _error='';bool _busy=false;Map<String,dynamic>? _request;
  Future<void> _save() async {
    if(!_form.currentState!.validate()){return;}FocusScope.of(context).unfocus();setState((){_busy=true;_error='';});
    _request??={'operationId':_operation,if(widget.kind=='farm')...{'name':_name.text.trim(),'region':_region.text.trim()}else...{'farmId':_farm,'date':_date.text.trim(),'assignee':_assignee.text.trim()},'note':_note.text.trim()};
    try{await widget.client.call(widget.kind=='farm'?'photos.farmCreate':'photos.visitCreate',params:_request);if(mounted){Navigator.pop(context,true);}}
    catch(e){await widget.onAuthError(e);if(mounted){setState(()=>_error=e is PlatformAuthFailure?e.message:'저장 응답을 확인하지 못했습니다. 다시 저장해 주세요.');}}
    finally{if(mounted){setState(()=>_busy=false);}}
  }
  @override
  void dispose(){for(final c in [_name,_region,_note,_date,_assignee]){c.dispose();}super.dispose();}
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.kind=='farm'?'농가 등록':'방문 등록'),actions:[TextButton(onPressed:_busy?null:_save,child:const Text('저장'))]),body:Form(key:_form,child:ListView(padding:const EdgeInsets.all(16),children:[
    if(_error.isNotEmpty)Text(_error),if(_busy)const LinearProgressIndicator(),
    if(widget.kind=='farm')...[
      TextFormField(controller:_name,readOnly:_request!=null,maxLength:120,decoration:const InputDecoration(labelText:'농가명'),validator:(v)=>v==null||v.trim().isEmpty?'농가명을 입력해 주세요.':null),
      TextFormField(controller:_region,readOnly:_request!=null,maxLength:200,decoration:const InputDecoration(labelText:'주소·지역 (동명 농가 구분)')),
    ]else...[
      DropdownButtonFormField<String>(initialValue:_farm,isExpanded:true,decoration:const InputDecoration(labelText:'농가'),items:widget.farms.map((f)=>DropdownMenuItem(value:f['id'] as String,child:Text('${f['name']} · ${f['region']}'))).toList(),onChanged:_request!=null?null:(v)=>setState(()=>_farm=v),validator:(v)=>v==null?'농가를 선택해 주세요.':null),
      TextFormField(controller:_date,readOnly:_request!=null,decoration:const InputDecoration(labelText:'방문일 (YYYY-MM-DD)'),validator:(v)=>v==null||!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v.trim())?'방문일을 입력해 주세요.':null),
      TextFormField(controller:_assignee,readOnly:_request!=null,maxLength:120,decoration:const InputDecoration(labelText:'담당자')),
    ],
    TextFormField(controller:_note,readOnly:_request!=null,maxLength:1500,maxLines:3,decoration:const InputDecoration(labelText:'메모')),
    if(_request!=null)const Text('응답이 끊겼다면 위 저장 버튼으로 같은 요청을 다시 확인합니다. 내용을 바꾸려면 뒤로 나가 새로 등록하세요.'),
  ])));
}

class _ClassifyPage extends StatefulWidget {
  const _ClassifyPage({required this.client,required this.photos,required this.farms,required this.onAuthError});
  final AppsScriptPlatformClient client;final List<Map<String,dynamic>> photos,farms;final Future<void> Function(Object) onAuthError;
  @override
  State<_ClassifyPage> createState()=>_ClassifyPageState();
}
class _ClassifyPageState extends State<_ClassifyPage> {
  final _form=GlobalKey<FormState>();final _operation=const Uuid().v4();final _crop=TextEditingController();
  String? _farm;String _visit='keep',_error='';List<Map<String,dynamic>> _visits=[];int? _nextVisits;bool _busy=false,_loading=false;Map<String,dynamic>? _request;
  @override
  void initState(){super.initState();final crops=widget.photos.map((p)=>p['crop'] as String? ?? '').toSet();if(crops.length==1){_crop.text=crops.first;}}
  Future<void> _choose(String? farm) async {
    setState((){_farm=farm;_visit='keep';_visits=[];_loading=true;_error='';});
    try{final result=await widget.client.call('photos.library',params:{'farmId':farm});if(mounted){setState((){_visits=List<Map<String,dynamic>>.from(result['visits'] as List);_nextVisits=result['nextOffset'] as int?;});}}
    catch(e){await widget.onAuthError(e);if(mounted){setState(()=>_error=e is PlatformAuthFailure?e.message:'방문 목록을 불러오지 못했습니다.');}}
    finally{if(mounted){setState(()=>_loading=false);}}
  }
  Future<void> _moreVisits() async {
    setState(()=>_loading=true);
    try{final result=await widget.client.call('photos.library',params:{'farmId':_farm,'offset':_nextVisits});if(mounted){setState((){_visits.addAll(List<Map<String,dynamic>>.from(result['visits'] as List));_nextVisits=result['nextOffset'] as int?;});}}
    catch(e){await widget.onAuthError(e);if(mounted){setState(()=>_error=e is PlatformAuthFailure?e.message:'방문 목록을 불러오지 못했습니다.');}}
    finally{if(mounted){setState(()=>_loading=false);}}
  }
  Future<void> _save() async {
    if(!_form.currentState!.validate()){return;}FocusScope.of(context).unfocus();setState((){_busy=true;_error='';});
    _request??={'operationId':_operation,'targets':widget.photos.map((p)=>{'id':p['id'],'expectedVersion':p['metadataVersion']??p['createdAt']}).toList(),'changes':{'farmId':_farm,'crop':_crop.text.trim(),if(_visit!='keep')'visitId':_visit}};
    try{await widget.client.call('photos.classify',params:_request);if(mounted){Navigator.pop(context,true);}}
    catch(e){await widget.onAuthError(e);if(mounted){setState(()=>_error=e is PlatformAuthFailure?e.message:'저장 응답을 확인하지 못했습니다. 다시 저장해 주세요.');}}
    finally{if(mounted){setState(()=>_busy=false);}}
  }
  @override
  void dispose(){_crop.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('사진 ${widget.photos.length}장 분류'),actions:[TextButton(key:const Key('library-classify-save'),onPressed:_busy||_loading?null:_save,child:const Text('변경 저장'))]),body:Form(key:_form,child:ListView(padding:const EdgeInsets.all(16),children:[
    if(_error.isNotEmpty)Text(_error),if(_busy||_loading)const LinearProgressIndicator(),
    const Text('선택한 사진에만 적용합니다. 품종·촬영일·주소·메모는 사진 상세에서 수정할 수 있습니다.'),
    DropdownButtonFormField<String>(key:const Key('library-farm'),initialValue:_farm,isExpanded:true,decoration:const InputDecoration(labelText:'농가'),items:widget.farms.map((f)=>DropdownMenuItem(value:f['id'] as String,child:Text('${f['name']} · ${f['region']}'))).toList(),onChanged:_request!=null||_loading?null:_choose,validator:(v)=>v==null?'농가를 선택해 주세요.':null),
    TextFormField(key:const Key('library-crop'),controller:_crop,readOnly:_request!=null,maxLength:80,decoration:const InputDecoration(labelText:'작물'),validator:(v)=>v==null||v.trim().isEmpty?'작물을 입력해 주세요.':null),
    DropdownButtonFormField<String>(key:ValueKey('library-visit-$_farm'),initialValue:_visit,isExpanded:true,decoration:const InputDecoration(labelText:'방문 연결'),items:[const DropdownMenuItem(value:'keep',child:Text('같은 농가의 기존 연결 유지')),const DropdownMenuItem(value:'',child:Text('방문 연결 해제')),for(final v in _visits)DropdownMenuItem(value:v['id'] as String,child:Text('${v['date']} · ${v['assignee']}'))],onChanged:_request!=null||_loading?null:(v)=>setState(()=>_visit=v??'keep')),
    if(_nextVisits!=null)TextButton(onPressed:_request!=null||_loading?null:_moreVisits,child:const Text('이전 방문 더 불러오기')),
    const Padding(padding:EdgeInsets.only(top:12),child:Text('농가를 바꾸면 이전 농가의 방문 연결은 해제됩니다. 방문일을 촬영일로 대신 입력하지 않습니다.')),
  ])));
}

class _DiscordConnectPage extends StatefulWidget {
  const _DiscordConnectPage({required this.client,required this.settings,required this.onAuthError});
  final AppsScriptPlatformClient client;final Map<String,dynamic> settings;final Future<void> Function(Object) onAuthError;
  @override
  State<_DiscordConnectPage> createState()=>_DiscordConnectPageState();
}
class _DiscordConnectPageState extends State<_DiscordConnectPage> {
  final _channel=TextEditingController(),_token=TextEditingController();bool _busy=false;String _error='';
  @override
  void initState(){super.initState();_channel.text=widget.settings['channelId'] as String? ?? '';}
  Future<void> _save({bool disconnect=false}) async {
    setState((){_busy=true;_error='';});
    try{await widget.client.call('discord.configure',params:{'expectedVersion':widget.settings['version']??'0',if(disconnect)'disconnect':true,if(!disconnect)...{'channelId':_channel.text.trim(),'botToken':_token.text.trim()}});if(mounted){Navigator.pop(context,true);}}
    catch(e){await widget.onAuthError(e);if(mounted){setState(()=>_error=e is PlatformAuthFailure?e.message:'연결하지 못했습니다. 다시 확인해 주세요.');}}
    finally{if(mounted){_token.clear();setState(()=>_busy=false);}}
  }
  @override
  void dispose(){_channel.dispose();_token.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Discord 수집 설정'),actions:[TextButton(onPressed:_busy?null:_save,child:const Text('연결 저장'))]),body:ListView(padding:const EdgeInsets.all(16),children:[
    const Text('앱 알림용 웹훅과 별개의 읽기 봇입니다. 회사 공유용 일반 텍스트 채널 한 곳만 지정하세요. 이 채널 사진은 앱의 사진 조회 권한이 있는 직원에게 표시됩니다.'),
    const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('Discord 개발자 포털에서 봇의 Message Content Intent를 켜고, 채널 보기·메시지 기록 읽기 권한으로 서버에 초대하세요. 연결 시점 이전 메시지는 가져오지 않습니다.')),
    if(_error.isNotEmpty)Text(_error),if(_busy)const LinearProgressIndicator(),
    TextField(controller:_channel,enabled:!_busy,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'채널 ID (숫자)')),
    TextField(controller:_token,enabled:!_busy,obscureText:true,autocorrect:false,enableSuggestions:false,decoration:const InputDecoration(labelText:'봇 토큰',helperText:'서버 비공개 설정에만 보관하며 다시 표시하지 않습니다.')),
    if(widget.settings['configured']==true)TextButton(onPressed:_busy?null:()=>_save(disconnect:true),child:const Text('수집 연결 해제 (저장된 사진 유지)')),
  ]));
}
