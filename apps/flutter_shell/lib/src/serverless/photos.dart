import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'client.dart';
import 'photo_store.dart';
import 'photo_bulk_edit.dart';
import 'photo_library.dart';
import 'photo_repository.dart';
import '../ui/hangyeol_theme.dart';
export 'photo_store.dart';
export 'photo_repository.dart';

String photoNotificationLabel(String? value)=>const {'pending':'Discord 전송 대기','sending':'Discord 전송 확인 중','sent':'Discord 알림 완료','failed':'Discord 전송 실패','uncertain':'Discord 채널 확인 필요','not_applicable':'Discord에서 가져옴'}[value]??'알림 대기';

class OnlinePhotosPage extends StatefulWidget {
  const OnlinePhotosPage({super.key,required this.client,required this.email,required this.canCreate,
    required this.owner,this.canManage=false,required this.onAuthError,this.repository,this.draftStore,this.pickPhotos,this.initialFilter,this.settingsRevision=0,this.useAccountStorage=false});
  final AppsScriptPlatformClient client;
  final String email;
  final int settingsRevision;
  final bool canCreate,owner,canManage;
  final bool useAccountStorage;
  final Future<void> Function(Object) onAuthError;
  final PhotoRepository? repository;
  final PhotoFilter? initialFilter;
  final PhotoDraftStore? draftStore;
  final Future<List<File>> Function(ImageSource)? pickPhotos;
  @override
  State<OnlinePhotosPage> createState()=>_OnlinePhotosPageState();
}
class _PhotoEntry {
  _PhotoEntry(this.kind,{this.photo,this.label});
  final String kind;
  final Map<String,dynamic>? photo;
  final String? label;
}
class _OnlinePhotosPageState extends State<OnlinePhotosPage> {
  PhotoDraftStore? _store;
  late PhotoRepository _repository;
  List<Map<String,dynamic>> _drafts=[],_photos=[];
  Map<String,dynamic>? _config;
  Map<String,List<String>> _suggestions={};
  Map<String,int> _groups={};
  final _search=TextEditingController();
  final _searchFocus=FocusNode();
  String _error='',_field='all',_groupBy='all',_query='',_activeUpload='';
  final _selected=<String,Map<String,dynamic>>{};
  bool _selecting=false;
  bool _exact=false;
  bool _loading=false,_adding=false,_sending=false,_viewing=false;
  int? _next;
  int _total=0,_loadVersion=0,_thumbVersion=0,_sent=0,_sendTotal=0,_prepared=0,_prepareTotal=0;
  @override
  void initState(){super.initState();final filter=widget.initialFilter;if(filter!=null){_field=filter.field;_query=filter.value;_search.text=filter.value;_exact=true;}_repository=widget.repository??PhotoRepository(widget.client,onAuthError:_fail);_open();}
  @override
  void didUpdateWidget(covariant OnlinePhotosPage oldWidget){
    super.didUpdateWidget(oldWidget);
    if(oldWidget.settingsRevision!=widget.settingsRevision){_refresh(force:true);}
  }
  Future<void> _open() async {
    try{
      if(widget.draftStore!=null){_store=widget.draftStore;}
      else if(widget.repository==null||widget.useAccountStorage){
        final root=_repository.cacheDirectory?.parent??await photoAccountDirectory(widget.client,widget.email);
        _store=PhotoDraftStore(root);
        _repository.cacheDirectory=Directory('${_store!.directory.path}/cache');
      }
      if(_store!=null){final drafts=await _store!.load();
        final pending=await _store!.removeStored(drafts);if(!mounted){return;}setState(()=>_drafts=pending);}
      if(mounted){await _refresh();}
    }catch(e){await _fail(e);}
  }
  Future<void> _fail(Object error) async {
    if(!mounted){return;}
    if(error is PlatformAuthFailure&&['AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'].contains(error.code)){await widget.onAuthError(error);}
    if(mounted){setState(()=>_error=error is PlatformAuthFailure?error.message:'처리하지 못했습니다. 전송하지 못한 사진은 기기에 보관되어 있습니다.');}
  }
  Future<void> _refresh({bool more=false,bool force=false}) async {
    if(more&&(_loading||_next==null)){return;}
    final version=++_loadVersion,token=widget.client.token;
    setState((){_loading=true;_error='';if(force){_thumbVersion++;}});
    try{
      final result=await _repository.list(query:_query,field:_field,groupBy:_groupBy,offset:more?_next??0:0,force:force,exact:_exact);
      if(!mounted||version!=_loadVersion||token!=widget.client.token){return;}
      final combined=<String,Map<String,dynamic>>{if(more)for(final photo in _photos)photo['id'] as String:photo,
        for(final photo in List<Map<String,dynamic>>.from(result['photos'] as List))photo['id'] as String:photo};
      setState((){
        _photos=combined.values.toList();_next=result['nextOffset'] as int?;_total=result['total'] as int? ?? _photos.length;
        _config=Map<String,dynamic>.from(result['config'] as Map? ?? {});
        _suggestions=(result['suggestions'] as Map? ?? {}).map((k,v)=>MapEntry(k as String,List<String>.from(v as List)));
        _groups=(result['groups'] as Map? ?? {}).map((k,v)=>MapEntry(k as String,v as int));
      });
    }catch(e){if(version==_loadVersion&&token==widget.client.token){await _fail(e);}}
    finally{if(mounted&&version==_loadVersion){setState(()=>_loading=false);}}
  }
  void _applySearch(){if(_selecting){return;}_searchFocus.unfocus();setState((){_query=_search.text.trim();_exact=false;});_refresh();}
  Future<List<File>> _pick(ImageSource source) async {
    if(widget.pickPhotos!=null){return widget.pickPhotos!(source);}
    if(Platform.isAndroid||Platform.isIOS){
      if(source==ImageSource.camera){final photo=await ImagePicker().pickImage(source:source);return photo==null?[]:[File(photo.path)];}
      return (await ImagePicker().pickMultiImage()).map((p)=>File(p.path)).toList();
    }
    return (await openFiles(acceptedTypeGroups:[const XTypeGroup(label:'사진',extensions:['jpg','jpeg','png','webp','heic','heif'])])).map((p)=>File(p.path)).toList();
  }
  Future<void> _register(ImageSource source) async {
    if(_store==null||_adding||_sending||!widget.canCreate){return;}
    final token=widget.client.token;
    try{
      final files=await _pick(source);if(files.isEmpty||!mounted||token!=widget.client.token){return;}
      if(files.length>100){throw PlatformAuthFailure('PHOTO_COUNT','한 번에 최대 100장을 선택해 주세요.');}
      final meta=await Navigator.of(context).push<Map<String,dynamic>>(MaterialPageRoute(builder:(_)=>_PhotoForm(count:files.length)));
      if(meta==null||!mounted||token!=widget.client.token){return;}
      setState((){_adding=true;_prepared=0;_prepareTotal=files.length;_error='';});
      final created=await _store!.addBatch(files,meta,_drafts,camera:source==ImageSource.camera,onProgress:(done,total){if(mounted){setState((){_prepared=done;_prepareTotal=total;});}});
      if(!mounted||token!=widget.client.token){return;}setState(()=>_drafts=[..._drafts,...created]);
      setState(()=>_adding=false);await _sendAll(only:created);
    }catch(e){if(token==widget.client.token){await _fail(e);}}
    finally{if(mounted){setState(()=>_adding=false);}}
  }
  Future<void> _sendAll({List<Map<String,dynamic>>? only}) async {
    final store=_store;if(store==null||_sending||_adding||!widget.canCreate){return;}
    final selected=List<Map<String,dynamic>>.from(only??_drafts.where((d)=>d['status']!='stored'));
    if(selected.isEmpty){return;}
    final token=widget.client.token;setState((){_sending=true;_sent=0;_sendTotal=selected.length;_error='';});
    try{
      for(final draft in selected){
        if(!mounted||token!=widget.client.token||!widget.canCreate){break;}
        final id=draft['requestId'] as String;setState((){_activeUpload=id;draft.remove('error');});
        try{
          final bytes=await store.originalBytes(id),preview=await store.previewBytes(id);
          if(!mounted||token!=widget.client.token){break;}
          final response=await widget.client.call('photos.upload',params:{...draft,'base64':base64Encode(bytes),if(preview!=null)'thumbnail':base64Encode(preview)});
          if(!mounted||token!=widget.client.token){break;}
          final photo=Map<String,dynamic>.from(response['photo'] as Map);
          if(photo['state']!='stored'||photo['id'] is! String||!RegExp(r'^[a-f0-9-]{36}$').hasMatch(photo['id'] as String)){throw PlatformAuthFailure('PHOTO_VERIFY_FAILED','저장 상태를 확인하지 못했습니다. 사진은 기기에 보관됩니다.');}
          draft['status']='stored';draft['photo']=photo;await store.save(_drafts);
          if(preview!=null&&response['duplicate']!=true){await _repository.rememberThumbnail(photo,preview);}
          if(response['duplicate']==true&&mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('이미 저장된 사진입니다. 기존 사진에 연결했으며 사진 정보는 유지했습니다.')));}
          final pending=await store.removeStored(_drafts);
          if(!mounted||token!=widget.client.token){break;}
          setState((){
            _drafts=pending;_sent++;
            if(photoMatches(photo,_field,_query,exact:_exact)&&!_photos.any((p)=>p['id']==photo['id'])){_photos=[photo,..._photos];_total++;}
          });
        }catch(error){
          draft['status']='failed';draft['error']=error is PlatformAuthFailure?error.message:'전송하지 못했습니다.';
          await store.save(_drafts);
          if(token==widget.client.token){await _fail(error);}
          if(error is PlatformAuthFailure&&['CONNECTION_FAILED','BUSY','AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','FORBIDDEN','PHOTO_GOOGLE_PERMISSION','SESSION_CHANGED'].contains(error.code)){break;}
        }
      }
    }finally{if(mounted){setState((){_sending=false;_activeUpload='';});}}
    if(mounted&&token==widget.client.token){await _refresh(force:true);}
  }
  Future<void> _library() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>PhotoLibraryPage(client:widget.client,repository:_repository,onAuthError:widget.onAuthError,openPhoto:(photo) async {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>PhotoDetailPage(photo:photo,repository:_repository,client:widget.client,canEdit:widget.canCreate,onAuthError:widget.onAuthError,onBrowse:_browse)));
    })));
    if(mounted){await _refresh(force:true);}
  }
  Future<void> _browse(String field,String value) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>Scaffold(
      appBar:AppBar(title:Text('${photoFields[field]} · $value')),
      body:OnlinePhotosPage(client:widget.client,email:widget.email,canCreate:widget.canCreate,owner:false,
        canManage:widget.canManage||widget.owner,onAuthError:widget.onAuthError,repository:_repository,initialFilter:PhotoFilter(field,value)),
    )));
  }
  bool _canEdit(Map<String,dynamic> photo)=>widget.canCreate&&(widget.owner||widget.canManage||photo['email']==widget.email);
  bool _canSelect(Map<String,dynamic> photo)=>_canEdit(photo)&&photo['notification']!='sending';
  void _cancelSelection(){setState((){_selecting=false;_selected.clear();});}
  void _togglePhoto(Map<String,dynamic> photo){
    if(!_canSelect(photo)){return;}
    final id=photo['id'] as String;
    if(!_selected.containsKey(id)&&_selected.length>=100){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('한 번에 최대 100장까지 선택할 수 있습니다.')));return;}
    _searchFocus.unfocus();setState((){_selecting=true;if(_selected.containsKey(id)){_selected.remove(id);}else{_selected[id]=Map<String,dynamic>.from(photo);}});
  }
  void _selectLoaded(){
    setState((){for(final photo in _photos.where(_canSelect)){
      final id=photo['id'] as String;if(_selected.containsKey(id)){continue;}if(_selected.length>=100){break;}_selected[id]=Map<String,dynamic>.from(photo);
    }});
  }
  Future<void> _editSelected() async {
    if(_selected.isEmpty){return;}
    final token=widget.client.token,count=_selected.length;
    final result=await Navigator.of(context).push<List<Map<String,dynamic>>>(MaterialPageRoute(builder:(_)=>PhotoBulkEditPage(
      client:widget.client,photos:_selected.values.map((p)=>Map<String,dynamic>.from(p)).toList(),onAuthError:widget.onAuthError)));
    if(result==null||!mounted||token!=widget.client.token){return;}
    _cancelSelection();await _refresh(force:true);
    if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('사진 $count장 정보를 수정했습니다.')));}
  }
  Widget _selectionBar()=>Material(color:Theme.of(context).colorScheme.surfaceContainerLow,child:Padding(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text('선택 ${_selected.length}/100장',key:const Key('photo-selected-count'))),
      TextButton(key:const Key('photo-select-loaded'),onPressed:_loading?null:_selectLoaded,child:const Text('목록 선택')),
      FilledButton.icon(key:const Key('photo-edit-selected'),onPressed:_selected.isEmpty?null:_editSelected,icon:const Icon(Icons.edit_outlined,size:18),label:const Text('수정')),
      IconButton(tooltip:'선택 취소',onPressed:_cancelSelection,icon:const Icon(Icons.close)),
    ]),
    Text(widget.canManage||widget.owner?'목록 선택은 현재 불러온 사진에 적용됩니다.':'본인이 등록한 사진만 선택할 수 있습니다.',style:Theme.of(context).textTheme.bodySmall),
  ])));
  Future<void> _view(Map<String,dynamic> photo) async {
    if(_viewing){return;}setState(()=>_viewing=true);
    try{await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>PhotoDetailPage(
      photo:photo,repository:_repository,client:widget.client,onAuthError:widget.onAuthError,onBrowse:_browse,
      canEdit:_canEdit(photo))));
      if(mounted){await _refresh(force:true);}
    }catch(e){await _fail(e);}finally{if(mounted){setState(()=>_viewing=false);}}
  }
  Future<void> _retry(Map<String,dynamic> photo) async {
    var confirmed=false;
    if(photo['notification']=='uncertain'||photo['notification']=='sending'){
      confirmed=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Discord 채널을 확인했나요?'),content:const Text('이 사진이 포함된 묶음이 이미 올라갔을 수 있습니다. 같은 묶음을 재전송하면 중복 메시지가 생길 수 있습니다.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('확인 후 재전송'))]))??false;
      if(!confirmed){return;}
    }
    try{await widget.client.call('photos.retry',params:{'id':photo['id'],'confirmDuplicateRisk':confirmed});if(mounted){await _refresh(force:true);}}catch(e){await _fail(e);}
  }
  Widget _header()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[const Expanded(child:Text('작황 사진',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700,color:kHangyeolInk,letterSpacing:-0.3))),
      if((widget.canManage||widget.owner)&&widget.initialFilter==null)IconButton(key:const Key('photo-open-library'),tooltip:'사진 정리 · 농가·방문·Discord 수집',onPressed:_sending||_adding?null:_library,icon:const Icon(Icons.inventory_2_outlined)),
      if(widget.canCreate&&!_selecting)IconButton(key:const Key('photo-start-selection'),tooltip:'여러 사진 정보 수정',onPressed:_sending||_adding||!_photos.any(_canSelect)?null:(){_searchFocus.unfocus();setState(()=>_selecting=true);},icon:const Icon(Icons.checklist)),
      IconButton(tooltip:'사진 목록 새로고침',onPressed:_loading?null:()=>_refresh(force:true),icon:const Icon(Icons.refresh))]),
    if(_loading||_adding||_viewing)const LinearProgressIndicator(minHeight:2),
    if(_error.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text(_error,style:TextStyle(color:Theme.of(context).colorScheme.error))),
    if(_config!=null&&_config?['ready']!=true)const Padding(padding:EdgeInsets.symmetric(vertical:10),child:Text('최초 관리자가 설정에서 사진 저장소를 연결해 주세요.',style:TextStyle(color:kHangyeolMuted))),
    if(widget.canCreate&&widget.initialFilter==null)Wrap(spacing:8,children:[
      FilledButton.icon(key:const Key('photo-select-many'),onPressed:_selecting||_adding||_sending||_store==null?null:()=>_register(ImageSource.gallery),icon:const Icon(Icons.photo_library_outlined,size:18),label:const Text('사진 여러 장 선택')),
      if(Platform.isAndroid||Platform.isIOS)OutlinedButton.icon(onPressed:_selecting||_adding||_sending||_store==null?null:()=>_register(ImageSource.camera),icon:const Icon(Icons.camera_alt_outlined,size:18),label:const Text('촬영'))]),
    if(_adding)Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Text('사진 준비 $_prepared/$_prepareTotal장',style:const TextStyle(fontSize:12,color:kHangyeolMuted))),
    if(_sending)...[Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Text('업로드 $_sent/$_sendTotal장 완료 · 사진은 순서대로 전송됩니다.',style:const TextStyle(fontSize:12,color:kHangyeolMuted))),LinearProgressIndicator(value:_sendTotal==0?null:_sent/_sendTotal,minHeight:2)],
    const SizedBox(height:10),
    Row(children:[
      Expanded(child:DropdownButtonFormField<String>(key:ValueKey('photo-field-$_field'),initialValue:_field,isExpanded:true,
        decoration:InputDecoration(labelText:'검색 기준',isDense:true,filled:true,fillColor:kHangyeolSurface,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none)),
        items:photoFields.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),
        onChanged:_selecting?null:(value){if(value!=null){setState((){_field=value;_query=_search.text.trim();_exact=false;});_refresh();}})),
      const SizedBox(width:8),
      Expanded(child:DropdownButtonFormField<String>(key:ValueKey('photo-group-$_groupBy'),initialValue:_groupBy,isExpanded:true,
        decoration:InputDecoration(labelText:'보기 기준',isDense:true,filled:true,fillColor:kHangyeolSurface,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none)),
        items:photoFields.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.key=='all'?'최근 등록순':'${e.value}별'))).toList(),
        onChanged:_selecting?null:(value){if(value!=null){setState(()=>_groupBy=value);_refresh();}})),
    ]),const SizedBox(height:8),
    RawAutocomplete<String>(textEditingController:_search,focusNode:_searchFocus,
      optionsBuilder:(value)=>_selecting?<String>[]:photoSuggestions(_suggestions,_field,value.text),
      onSelected:(_)=>_applySearch(),
      fieldViewBuilder:(context,controller,focus,submit)=>TextField(key:const Key('photo-search-input'),controller:controller,focusNode:focus,
        readOnly:_selecting,textInputAction:TextInputAction.search,onTapOutside:(_)=>focus.unfocus(),onSubmitted:(_)=>_applySearch(),
        decoration:InputDecoration(labelText:'농가·작물·품종·촬영일·주소·메모 검색',hintText:'예: 가명A, 루비, 2026-11',filled:true,fillColor:kHangyeolSurface,isDense:true,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:kHangyeolPrimary,width:1.4)),
          suffixIcon:IconButton(tooltip:'사진 검색',onPressed:_selecting?null:_applySearch,icon:const Icon(Icons.search)))),
      optionsViewBuilder:(context,select,options)=>Material(color:kHangyeolCanvas,elevation:4,borderRadius:BorderRadius.circular(12),child:ConstrainedBox(
        constraints:const BoxConstraints(maxHeight:200),child:ListView(shrinkWrap:true,padding:EdgeInsets.zero,
          children:options.map((v)=>ListTile(dense:true,title:Text(v),onTap:()=>select(v))).toList()))),
    ),
    if(_exact)Align(alignment:Alignment.centerLeft,child:InputChip(key:const Key('photo-exact-filter'),label:Text('${photoFields[_field]}: $_query'),
      onDeleted:_selecting?null:(){_search.clear();setState((){_query='';_exact=false;});_refresh();})),
    Padding(padding:const EdgeInsets.fromLTRB(2,8,2,4),child:Text('사진 $_total장 · ${_groupBy=='all'?'최근 등록순':'${photoFields[_groupBy]}별 보기'}',style:const TextStyle(fontSize:12,color:kHangyeolMuted))),
    if(_config?['ready']==true&&_config?['discordConfigured']!=true)const Padding(padding:EdgeInsets.only(bottom:6),child:Text('Discord 미연결 · 사진은 정상 저장되며 알림은 대기합니다.',style:TextStyle(fontSize:12,color:kHangyeolMuted))),
    const Divider(height:1,color:kHangyeolDivider),
  ]);
  List<_PhotoEntry> _entries(){
    final entries=<_PhotoEntry>[];
    if(_drafts.isNotEmpty){entries.add(_PhotoEntry('pending',label:'이 기기의 전송 대기 ${_drafts.length}장'));for(final d in _drafts){entries.add(_PhotoEntry('draft',photo:d));}}
    String? lastGroup;
    for(final photo in _photos){
      final group=photo[_groupBy] as String? ?? '';
      if(_groupBy!='all'&&group!=lastGroup){entries.add(_PhotoEntry('group',label:'${group.isEmpty?'미입력':group}${_groups.containsKey(group)?' · ${_groups[group]}장':''}'));lastGroup=group;}
      entries.add(_PhotoEntry('photo',photo:photo));
    }
    if(_next!=null){entries.add(_PhotoEntry('more'));}
    if(_photos.isEmpty&&!_loading&&_config?['ready']==true){entries.add(_PhotoEntry('empty',label:_query.isEmpty?'등록된 사진이 없습니다.':'조건에 맞는 사진이 없습니다.'));}
    return entries;
  }
  Widget _photoCard(Map<String,dynamic> photo){
    final note=(photo['note'] as String? ?? '').trim(),notification=(photo['notificationNote'] as String? ?? '').trim();
    final urgent=['failed','uncertain'].contains(photo['notification']);
    return Container(
      key:ValueKey('photo-${photo['id']}'),
      decoration:const BoxDecoration(color:kHangyeolCanvas,border:Border(bottom:BorderSide(color:kHangyeolDivider,width:0.8))),
      child:InkWell(
        onTap:_selecting?(_canSelect(photo)?()=>_togglePhoto(photo):null):()=>_view(photo),
        onLongPress:!_sending&&!_adding&&_canSelect(photo)?()=>_togglePhoto(photo):null,
        child:Padding(padding:const EdgeInsets.symmetric(horizontal:4,vertical:9),child:Row(children:[
          if(_selecting)Checkbox(key:ValueKey('photo-check-${photo['id']}'),value:_selected.containsKey(photo['id']),onChanged:_canSelect(photo)?(_)=>_togglePhoto(photo):null),
          SizedBox(width:58,height:58,child:ClipRRect(borderRadius:BorderRadius.circular(14),child:_PhotoThumbnail(
            key:ValueKey('thumb-${photo['id']}-${photo['previewVersion']}-$_thumbVersion'),repository:_repository,photo:photo))),
          const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
            Text('${(photo['farm'] as String? ?? '').isEmpty?'농가 미입력':photo['farm']} · ${(photo['crop'] as String? ?? '').isEmpty?'작물 미입력':photo['crop']} ${photo['variety']}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600,color:kHangyeolInk,height:1.25)),
            const SizedBox(height:2),
            Text('${photo['date']==''?'촬영일 미상':photo['date']} · ${photo['region']}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,color:kHangyeolMuted,height:1.25)),
            if(note.isNotEmpty)Text(note,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,color:kHangyeolMuted,height:1.25)),
            Text(notification.isEmpty?photoNotificationLabel(photo['notification'] as String?):notification,key:ValueKey('photo-notification-${photo['id']}'),
              maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:11,height:1.25,color:urgent?Theme.of(context).colorScheme.error:kHangyeolSubtle)),
          ])),
          if(!_selecting&&widget.canCreate&&!['sent','not_applicable'].contains(photo['notification'])&&photo['source']!='discord'&&(widget.canManage||widget.owner||photo['email']==widget.email))
            IconButton(tooltip:'Discord 전송 재시도',onPressed:_sending?null:()=>_retry(photo),icon:const Icon(Icons.send_outlined),iconSize:20),
        ])),
      ),
    );
  }
  Widget _draftCard(Map<String,dynamic> draft)=>Container(
    key:ValueKey('draft-${draft['requestId']}'),
    margin:const EdgeInsets.symmetric(vertical:4),
    decoration:BoxDecoration(color:kHangyeolSurface,borderRadius:BorderRadius.circular(12)),
    child:ListTile(
      leading:SizedBox(width:56,height:56,child:ClipRRect(borderRadius:BorderRadius.circular(12),child:_DraftThumbnail(store:_store!,id:draft['requestId'] as String))),
      title:Text('${draft['farm']} · ${draft['crop']}',style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600,color:kHangyeolInk)),
      subtitle:Text('${(draft['batchIndex'] as int? ?? 0)+1}/${draft['batchSize']??1} · ${draft['error']??'전송 대기 · 원본 보관 중'}',style:const TextStyle(fontSize:12,color:kHangyeolMuted)),
      trailing:_activeUpload==draft['requestId']?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2))
        :widget.canCreate?IconButton(tooltip:'사진 다시 전송',onPressed:_sending||_adding?null:()=>_sendAll(only:[draft]),icon:const Icon(Icons.cloud_upload_outlined)):null,
    ),
  );
  @override
  void dispose(){_search.dispose();_searchFocus.dispose();if(widget.repository==null){_repository.dispose();}super.dispose();}
  @override
  Widget build(BuildContext context){final entries=_entries();return ColoredBox(color:kHangyeolCanvas,child:Column(children:[if(_selecting)_selectionBar(),Expanded(child:RefreshIndicator(onRefresh:()=>_refresh(force:true),child:ListView.builder(
    padding:const EdgeInsets.fromLTRB(14,10,14,14),physics:const AlwaysScrollableScrollPhysics(),itemCount:entries.length+1,
    itemBuilder:(context,index){if(index==0){return _header();}final entry=entries[index-1];
      if(entry.kind=='photo'){return _photoCard(entry.photo!);}if(entry.kind=='draft'){return _draftCard(entry.photo!);}
      if(entry.kind=='more'){return TextButton(onPressed:_loading?null:()=>_refresh(more:true),child:const Text('더 보기'));}
      if(entry.kind=='pending'){return Row(children:[Expanded(child:Text(entry.label!,style:const TextStyle(fontWeight:FontWeight.w700,color:kHangyeolInk))),
        if(widget.canCreate)TextButton(onPressed:_sending||_adding?null:()=>_sendAll(),child:const Text('모두 재시도'))]);}
      return Padding(padding:const EdgeInsets.fromLTRB(4,12,4,6),child:Text(entry.label!,style:TextStyle(fontWeight:entry.kind=='group'?FontWeight.w700:FontWeight.normal,color:entry.kind=='group'?kHangyeolInk:kHangyeolMuted)));
    },
  )))]));}
}
class PhotoDetailPage extends StatefulWidget {
  const PhotoDetailPage({super.key,required this.photo,required this.repository,required this.client,required this.canEdit,required this.onAuthError,this.onBrowse});
  final Map<String,dynamic> photo;
  final PhotoRepository repository;
  final AppsScriptPlatformClient client;
  final bool canEdit;
  final Future<void> Function(String field,String value)? onBrowse;
  final Future<void> Function(Object) onAuthError;
  @override
  State<PhotoDetailPage> createState()=>_PhotoDetailPageState();
}
class _PhotoDetailPageState extends State<PhotoDetailPage> {
  late Map<String,dynamic> _photo;
  late Future<Uint8List> _image;
  bool _photoOnly=false;
  @override
  void initState(){super.initState();_photo=Map.from(widget.photo);_image=_load();}
  Future<Uint8List> _load() async {
    try{return await widget.repository.original(_photo);}catch(e){await widget.onAuthError(e);rethrow;}
  }
  Future<void> _edit() async {
    final saved=await Navigator.of(context).push<Map<String,dynamic>>(MaterialPageRoute(builder:(_)=>_PhotoForm(count:1,initial:_photo,onSave:(values) async {
      try{final result=await widget.client.call('photos.update',params:{...values,'id':_photo['id'],'expectedVersion':_photo['metadataVersion']??_photo['createdAt']});
        return Map<String,dynamic>.from(result['photo'] as Map);
      }catch(e){await widget.onAuthError(e);rethrow;}
    })));
    if(saved!=null&&mounted){setState(()=>_photo=saved);}
  }
  Widget _picture()=>ColoredBox(color:const Color(0xff14221d),child:FutureBuilder<Uint8List>(future:_image,builder:(context,snapshot){
    if(snapshot.hasError){return Center(child:TextButton.icon(onPressed:()=>setState(()=>_image=_load()),icon:const Icon(Icons.refresh),label:const Text('사진 다시 불러오기')));}
    if(snapshot.data==null){return const Center(child:CircularProgressIndicator());}
    return InteractiveViewer(key:const Key('photo-detail-zoom'),minScale:1,maxScale:8,child:SizedBox.expand(child:Image.memory(snapshot.data!,key:const Key('photo-detail-image'),fit:BoxFit.contain,
      errorBuilder:(context,error,stack)=>const Center(child:Text('이 기기에서 원본 형식을 지원하지 않습니다.',style:TextStyle(color:Colors.white))))));
  }));
  Widget _infoField(String field,String label){
    final value=(_photo[field] as String? ?? '').trim();
    final canBrowse=value.isNotEmpty&&photoFields.containsKey(field)&&widget.onBrowse!=null;
    final content=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label,style:Theme.of(context).textTheme.labelMedium),
      if(canBrowse)Row(children:[Expanded(child:Text(value,style:Theme.of(context).textTheme.bodyLarge?.copyWith(color:Theme.of(context).colorScheme.primary))),
        Icon(Icons.chevron_right,size:20,color:Theme.of(context).colorScheme.primary)])
      else SelectableText(value.isEmpty?'미입력':value,style:Theme.of(context).textTheme.bodyLarge),
    ]);
    return Padding(padding:const EdgeInsets.only(bottom:12),child:canBrowse
      ?Tooltip(message:'같은 $label 사진 보기',child:InkWell(key:Key('photo-browse-$field'),onTap:()=>widget.onBrowse!(field,value),
        child:ConstrainedBox(constraints:const BoxConstraints(minHeight:48),child:content)))
      :content);
  }
  Widget _info()=>SingleChildScrollView(key:const Key('photo-detail-info'),padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    for(final field in const {'farm':'농가','crop':'작물','variety':'품종','date':'촬영일','region':'주소·지역','note':'메모','email':'등록자','createdAt':'등록일','editedAt':'수정일'}.entries)
      _infoField(field.key,field.value),
  ]));
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('사진 상세'),actions:[
    IconButton(key:const Key('photo-detail-fullscreen'),tooltip:_photoOnly?'사진 정보 표시':'사진 크게 보기',onPressed:()=>setState(()=>_photoOnly=!_photoOnly),icon:Icon(_photoOnly?Icons.fullscreen_exit:Icons.fullscreen)),
    if(widget.canEdit)IconButton(key:const Key('photo-detail-edit'),tooltip:'사진 정보 수정',onPressed:_edit,icon:const Icon(Icons.edit_outlined)),
  ]),body:SafeArea(child:LayoutBuilder(builder:(context,size){
    if(_photoOnly){return _picture();}
    if(size.maxWidth>=700&&size.maxWidth>size.maxHeight){return Row(children:[Expanded(flex:7,child:_picture()),Expanded(flex:3,child:_info())]);}
    return Column(children:[Expanded(flex:3,child:_picture()),Expanded(flex:2,child:_info())]);
  })));
}
class _PhotoThumbnail extends StatefulWidget {
  const _PhotoThumbnail({super.key,required this.repository,required this.photo});
  final PhotoRepository repository;
  final Map<String,dynamic> photo;
  @override
  State<_PhotoThumbnail> createState()=>_PhotoThumbnailState();
}
class _PhotoThumbnailState extends State<_PhotoThumbnail>{
  late Future<Uint8List?> _bytes;
  @override
  void initState(){super.initState();_bytes=widget.repository.thumbnail(widget.photo);}
  @override
  Widget build(BuildContext context)=>FutureBuilder<Uint8List?>(future:_bytes,builder:(context,snapshot){
    if(snapshot.connectionState!=ConnectionState.done){return const ColoredBox(color:Color(0xffe7efe9),child:Center(child:SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))));}
    if(snapshot.data!=null){return Image.memory(snapshot.data!,key:const Key('photo-thumbnail-image'),fit:BoxFit.cover,cacheWidth:240,
      errorBuilder:(context,error,stack)=>const Icon(Icons.broken_image_outlined));}
    return InkWell(onTap:()=>setState(()=>_bytes=widget.repository.thumbnail(widget.photo)),child:const Tooltip(message:'미리보기 다시 불러오기',child:Icon(Icons.photo_outlined)));
  });
}
class _DraftThumbnail extends StatefulWidget {
  const _DraftThumbnail({required this.store,required this.id});final PhotoDraftStore store;final String id;
  @override
  State<_DraftThumbnail> createState()=>_DraftThumbnailState();
}
class _DraftThumbnailState extends State<_DraftThumbnail>{
  late final _bytes=widget.store.previewBytes(widget.id);
  @override
  Widget build(BuildContext context)=>FutureBuilder<Uint8List?>(future:_bytes,builder:(context,snapshot)=>snapshot.data==null
    ?const Icon(Icons.photo_outlined):Image.memory(snapshot.data!,fit:BoxFit.cover,errorBuilder:(context,error,stack)=>const Icon(Icons.photo_outlined)));
}
class _PhotoForm extends StatefulWidget {
  const _PhotoForm({required this.count,this.initial,this.onSave});final int count;
  final Map<String,dynamic>? initial;
  final Future<Map<String,dynamic>> Function(Map<String,dynamic>)? onSave;
  @override
  State<_PhotoForm> createState()=>_PhotoFormState();
}
class _PhotoFormState extends State<_PhotoForm>{
  final _form=GlobalKey<FormState>();
  final _fields={for(final k in ['farm','crop','variety','date','region','note'])k:TextEditingController()};
  bool _saving=false;String _error='';
  @override
  void initState(){super.initState();for(final e in _fields.entries){e.value.text=widget.initial?[e.key] as String? ?? '';}}
  Future<void> _save() async {
    if(_saving||!_form.currentState!.validate()){return;}
    final values=<String,dynamic>{for(final e in _fields.entries)e.key:e.value.text.trim()};
    if(widget.onSave==null){Navigator.pop(context,values);return;}
    setState((){_saving=true;_error='';});
    try{final saved=await widget.onSave!(values);if(mounted){Navigator.pop(context,saved);}}
    catch(e){if(mounted){setState(()=>_error=e is PlatformAuthFailure?e.message:'저장하지 못했습니다. 다시 시도해 주세요.');}}
    finally{if(mounted){setState(()=>_saving=false);}}
  }
  @override
  void dispose(){for(final c in _fields.values){c.dispose();}super.dispose();}
  @override
  Widget build(BuildContext context)=>PopScope(canPop:!_saving,child:Scaffold(appBar:AppBar(title:Text(widget.initial==null?'사진 ${widget.count}장 공통 정보':'사진 정보 수정',overflow:TextOverflow.ellipsis),actions:[if(widget.initial!=null)TextButton(key:const Key('photo-form-save'),onPressed:_saving?null:_save,child:Text(_saving?'저장 중…':'변경 저장'))]),body:Form(key:_form,child:ListView(padding:const EdgeInsets.all(16),children:[
    if(_saving)const LinearProgressIndicator(),
    if(_error.isNotEmpty)Text(_error,style:TextStyle(color:Theme.of(context).colorScheme.error)),
    if(widget.initial!=null)const Text('원본 사진은 유지하고 정보를 수정합니다. 이미 발송된 Discord 메시지는 그대로 유지됩니다.'),
    if(widget.initial==null)const Text('선택한 사진에 농가·작물·품종·주소를 함께 적용합니다. 촬영일을 비우면 각 사진의 촬영 정보를 사용하며, 확인되지 않으면 미상으로 남깁니다. Discord는 최대 10장씩 나눠 보냅니다.'),const SizedBox(height:16),
    for(final item in const {'farm':'농가명 *','crop':'작물 *','variety':'품종','date':'공통 촬영일 (YYYY-MM-DD)','region':'주소·지역','note':'메모'}.entries)
      Padding(padding:const EdgeInsets.only(bottom:12),child:TextFormField(key:Key('photo-form-${item.key}'),controller:_fields[item.key],enabled:!_saving,
        maxLength:const {'farm':120,'crop':80,'variety':100,'date':10,'region':200,'note':1500}[item.key],maxLines:item.key=='note'?3:1,
        decoration:InputDecoration(labelText:item.value),validator:(value){
          if(['farm','crop'].contains(item.key)&&(value??'').trim().isEmpty){return '필수 입력입니다.';}
          if(item.key=='date'&&(value??'').isNotEmpty){final date=DateTime.tryParse(value!);if(!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)||date==null||date.toIso8601String().substring(0,10)!=value){return '유효한 날짜를 입력해 주세요.';}}
          return null;
        })),
    if(widget.initial==null)FilledButton.icon(key:const Key('photo-form-save'),onPressed:_saving?null:_save,
      icon:Icon(widget.initial==null?Icons.cloud_upload_outlined:Icons.save_outlined),label:Text(widget.initial==null?'${widget.count}장 보관하고 전송':'변경 저장')),
  ]))));
}
