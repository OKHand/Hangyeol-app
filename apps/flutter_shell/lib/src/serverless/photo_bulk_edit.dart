import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'client.dart';

const bulkPhotoFields={'farm':'농가','crop':'작물','variety':'품종','date':'촬영일','region':'주소·지역','note':'메모'};
const _limits={'farm':120,'crop':80,'variety':100,'date':10,'region':200,'note':1500};

class PhotoBulkEditPage extends StatefulWidget {
  const PhotoBulkEditPage({super.key,required this.client,required this.photos,required this.onAuthError});
  final AppsScriptPlatformClient client;
  final List<Map<String,dynamic>> photos;
  final Future<void> Function(Object) onAuthError;
  @override
  State<PhotoBulkEditPage> createState()=>_PhotoBulkEditPageState();
}
class _PhotoBulkEditPageState extends State<PhotoBulkEditPage> {
  final _form=GlobalKey<FormState>();
  final _enabled=<String>{};
  final _fields={for(final key in bulkPhotoFields.keys)key:TextEditingController()};
  late final List<Map<String,dynamic>> _targets;
  late final String? _session;
  String _error='',_lastPatch='',_operationId='';
  bool _saving=false;
  @override
  void initState(){
    super.initState();_session=widget.client.token;
    _targets=widget.photos.map((p)=><String,dynamic>{'id':p['id'],'expectedVersion':p['metadataVersion']??p['createdAt']}).toList();
    for(final field in _fields.entries){
      final values=widget.photos.map((p)=>p[field.key] as String? ?? '').toSet();
      if(values.length==1){field.value.text=values.single;}
    }
  }
  Future<void> _save() async {
    if(_saving){return;}
    if(_enabled.isEmpty){setState(()=>_error='변경할 항목을 하나 이상 선택해 주세요.');return;}
    if(!_form.currentState!.validate()){return;}
    final changes=<String,dynamic>{for(final key in bulkPhotoFields.keys)if(_enabled.contains(key))key:_fields[key]!.text.trim()};
    final patch=jsonEncode(changes);
    if(patch!=_lastPatch){_lastPatch=patch;_operationId=const Uuid().v4();}
    setState((){_saving=true;_error='';});
    try{
      if(_session==null||widget.client.token!=_session){throw PlatformAuthFailure('SESSION_CHANGED','계정이 변경되었습니다. 다시 선택해 주세요.');}
      final result=await widget.client.call('photos.updateMany',params:{'operationId':_operationId,'targets':_targets,'changes':changes});
      final photos=List<Map<String,dynamic>>.from(result['photos'] as List);
      final expected=_targets.map((p)=>p['id']).toSet(),actual=photos.map((p)=>p['id']).toSet();
      if(photos.length!=_targets.length||actual.length!=expected.length||!actual.containsAll(expected)){
        throw PlatformAuthFailure('INVALID_RESULT','저장 결과를 확인하지 못했습니다. 같은 내용으로 다시 시도해 주세요.');
      }
      if(mounted){Navigator.pop(context,photos);}
    }catch(error){
      if(error is PlatformAuthFailure&&['AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'].contains(error.code)){await widget.onAuthError(error);}
      if(mounted){setState(()=>_error=error is PlatformAuthFailure?error.message:'저장하지 못했습니다. 입력한 내용을 유지했으니 다시 시도해 주세요.');}
    }finally{if(mounted){setState(()=>_saving=false);}}
  }
  @override
  void dispose(){for(final field in _fields.values){field.dispose();}super.dispose();}
  @override
  Widget build(BuildContext context)=>PopScope(canPop:!_saving,child:Scaffold(
    appBar:AppBar(title:Text('사진 ${_targets.length}장 정보 일괄 수정',overflow:TextOverflow.ellipsis),actions:[TextButton(key:const Key('bulk-save'),onPressed:_saving?null:_save,child:Text(_saving?'저장 중…':'변경 저장'))]),
    body:SafeArea(child:Form(key:_form,child:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,48),children:[
      if(_error.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(_error,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      if(_saving)const LinearProgressIndicator(),
      const Text('체크한 항목만 선택한 사진 모두에 적용합니다. 체크하지 않은 항목은 사진마다 기존 값을 유지합니다.'),
      const SizedBox(height:8),const Text('품종·촬영일·주소·메모는 체크한 뒤 비워 저장하면 지워집니다. 농가와 작물은 비울 수 없습니다.'),
      const SizedBox(height:8),const Text('원본 사진과 이미 발송된 Discord 메시지는 그대로 유지됩니다.'),
      for(final field in bulkPhotoFields.entries)Padding(padding:const EdgeInsets.only(top:8),child:Column(children:[
        CheckboxListTile(key:Key('bulk-enable-${field.key}'),contentPadding:EdgeInsets.zero,controlAffinity:ListTileControlAffinity.leading,dense:true,
          title:Text('${field.value} 변경'),value:_enabled.contains(field.key),onChanged:_saving?null:(value)=>setState((){if(value==true){_enabled.add(field.key);}else{_enabled.remove(field.key);}})),
        if(_enabled.contains(field.key))TextFormField(key:Key('bulk-field-${field.key}'),controller:_fields[field.key],enabled:!_saving,
          maxLength:_limits[field.key],maxLines:field.key=='note'?3:1,decoration:InputDecoration(labelText:field.key=='date'?'촬영일 (YYYY-MM-DD)':field.value),
          validator:(input){
            final value=(input??'').trim();
            if(['farm','crop'].contains(field.key)&&value.isEmpty){return '필수 입력입니다.';}
            if(field.key=='date'&&value.isNotEmpty){final day=DateTime.tryParse(value);
              if(!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)||day==null||day.toIso8601String().substring(0,10)!=value){return '유효한 날짜를 입력해 주세요.';}}
            return null;
          }),
      ])),
    ]))),
  ));
}
