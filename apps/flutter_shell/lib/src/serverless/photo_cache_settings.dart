import 'package:flutter/material.dart';
import 'photo_repository.dart';

class PhotoCacheSettingsDialog extends StatefulWidget {
  const PhotoCacheSettingsDialog({super.key,required this.repository});
  final PhotoRepository repository;
  @override
  State<PhotoCacheSettingsDialog> createState()=>_PhotoCacheSettingsDialogState();
}
class _PhotoCacheSettingsDialogState extends State<PhotoCacheSettingsDialog> {
  PhotoCacheStats? _stats;
  bool _busy=false;
  String _message='';
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    try{final value=await widget.repository.cacheStats();if(mounted){setState(()=>_stats=value);}}
    catch(_){if(mounted){setState(()=>_message='캐시 용량을 확인하지 못했습니다.');}}
  }
  Future<void> _clear() async {
    setState((){_busy=true;_message='';});
    try{await widget.repository.clearCache();final value=await widget.repository.cacheStats();
      if(mounted){setState((){_stats=value;_message='사진 캐시를 삭제했습니다.';});}}
    catch(_){if(mounted){setState(()=>_message='캐시를 모두 삭제하지 못했습니다. 다시 시도해 주세요.');}}
    finally{if(mounted){setState(()=>_busy=false);}}
  }
  @override
  Widget build(BuildContext context)=>AlertDialog(title:const Text('사진 캐시 관리'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Text('이 기기의 현재 계정 사진 캐시',style:TextStyle(fontWeight:FontWeight.bold)),
    if(_stats!=null)Text('${_stats!.files}개 · ${(_stats!.bytes/1024/1024).toStringAsFixed(1)} MB'),
    const SizedBox(height:8),const Text('미리보기와 열어본 사진의 임시 파일을 삭제합니다. Drive 원본과 업로드 대기 사진은 보존됩니다. 사진을 다시 열면 필요한 파일을 내려받습니다.'),
    const SizedBox(height:8),OutlinedButton.icon(key:const Key('photo-cache-clear'),onPressed:_busy?null:_clear,icon:const Icon(Icons.cleaning_services_outlined),label:const Text('사진 캐시 파일 삭제')),
    if(_busy)const LinearProgressIndicator(),
    if(_message.isNotEmpty)Text(_message),
  ])),actions:[TextButton(onPressed:_busy?null:()=>Navigator.pop(context),child:const Text('닫기'))]);
}
