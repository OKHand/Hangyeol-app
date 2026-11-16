import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'client.dart';

/// Company settings are authorized again by the API on every read and write.
class CompanyConnectionsPage extends StatefulWidget {
  const CompanyConnectionsPage({super.key,required this.client,required this.owner,required this.onAuthError,required this.onChanged});
  final AppsScriptPlatformClient client;
  final bool owner;
  final Future<void> Function(Object) onAuthError;
  final VoidCallback onChanged;
  @override
  State<CompanyConnectionsPage> createState()=>_CompanyConnectionsPageState();
}
class _CompanyConnectionsPageState extends State<CompanyConnectionsPage> {
  final _form=GlobalKey<FormState>();
  final _folder=TextEditingController(),_webhook=TextEditingController();
  Map<String,dynamic>? _config;
  bool _busy=false,_changeFolder=false,_changeDiscord=false;
  String _error='';
  @override
  void initState(){super.initState();_load();}
  Future<void> _fail(Object error) async {
    if(error is PlatformAuthFailure&&const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(error.code)){await widget.onAuthError(error);}
    if(mounted){setState(()=>_error=error is PlatformAuthFailure?error.message:'연결 설정을 처리하지 못했습니다. 다시 시도해 주세요.');}
  }
  Future<void> _load() async {
    setState((){_busy=true;_error='';});
    try{final value=await widget.client.call('photos.settings');if(mounted){setState(()=>_config=value);_folder.text=value['folderUrl'] as String? ?? '';}}
    catch(error){await _fail(error);}
    finally{if(mounted){setState(()=>_busy=false);}}
  }
  Future<void> _initialize() async {
    setState((){_busy=true;_error='';});
    try{await widget.client.call('photos.setup',params:{});widget.onChanged();if(mounted){await _load();}}
    catch(error){await _fail(error);}
    finally{if(mounted){setState(()=>_busy=false);}}
  }
  Future<void> _save() async {
    if(_busy||_config==null||!_form.currentState!.validate()){return;}
    setState((){_busy=true;_error='';});
    try{
      final value=await widget.client.call('photos.configure',params:{
        'expectedVersion':_config!['settingsVersion'],
        if(_changeFolder)'folderUrl':_folder.text.trim(),
        if(_changeDiscord)'webhook':_webhook.text.trim(),
      });
      widget.onChanged();
      if(mounted){setState((){_config=value;_changeFolder=false;_changeDiscord=false;});_webhook.clear();_folder.text=value['folderUrl'] as String? ?? '';
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('회사 연결 설정을 저장했습니다.')));}
    }catch(error){await _fail(error);}
    finally{if(mounted){setState(()=>_busy=false);}}
  }
  Future<void> _approve() async {
    final uri=Uri.tryParse(_config?['ownerSetupUrl'] as String? ?? '');
    if(uri==null||!AppsScriptPlatformClient.validApiUrl(uri)){return;}
    try{if(!await launchUrl(uri,mode:LaunchMode.externalApplication)){throw PlatformAuthFailure('BROWSER_UNAVAILABLE','Google 승인 화면을 열지 못했습니다.');}}
    catch(error){await _fail(error);}
  }
  @override
  void dispose(){_folder.dispose();_webhook.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>PopScope(canPop:!_busy,child:Scaffold(
    appBar:AppBar(title:const Text('회사 연결 설정',overflow:TextOverflow.ellipsis),actions:[
      TextButton(key:const Key('company-settings-save'),onPressed:_busy||_config?['ready']!=true||!(_changeFolder||_changeDiscord)?null:_save,child:const Text('저장')),
    ]),
    body:SafeArea(child:Form(key:_form,child:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('관리자·최초 관리자만 변경할 수 있습니다. 회사의 모든 직원에게 적용됩니다.'),
      if(_busy)const LinearProgressIndicator(),
      if(_error.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(_error,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      if(_config==null&&!_busy)TextButton(onPressed:_load,child:const Text('다시 불러오기')),
      if(_config!=null)...[
        if(_config!['ready']!=true)...[
          const SizedBox(height:16),const Text('최초 관리자가 사진 저장소를 먼저 연결해야 합니다.'),
          if(widget.owner)FilledButton(key:const Key('company-settings-initialize'),onPressed:_busy?null:_initialize,child:const Text('사진 저장소 최초 연결')),
        ]else...[
          const SizedBox(height:16),const Text('새 사진 저장 폴더',style:TextStyle(fontWeight:FontWeight.bold)),
          SelectableText(_config!['folderUrl'] as String? ?? '미연결'),
          CheckboxListTile(key:const Key('company-change-folder'),contentPadding:EdgeInsets.zero,title:const Text('새 사진 저장 폴더 변경'),value:_changeFolder,onChanged:_busy?null:(value)=>setState(()=>_changeFolder=value==true)),
          if(_changeFolder)TextFormField(key:const Key('company-folder-url'),controller:_folder,enabled:!_busy,maxLength:500,autocorrect:false,enableSuggestions:false,
            decoration:const InputDecoration(labelText:'Drive 폴더 주소 또는 폴더 ID'),validator:(value)=>(value??'').trim().isEmpty?'폴더 주소를 입력해 주세요.':null),
          const Text('변경 후 새로 업로드하는 사진부터 적용됩니다. 기존 사진과 관리대장은 이동하지 않습니다. 사진 저장 서비스가 파일을 추가할 수 있는 폴더를 선택해 주세요.',style:TextStyle(fontSize:12)),
          const Divider(height:32),const Text('Discord 알림',style:TextStyle(fontWeight:FontWeight.bold)),
          Text(_config!['discordConfigured']==true?'연결됨':'미연결'),
          CheckboxListTile(key:const Key('company-change-discord'),contentPadding:EdgeInsets.zero,title:const Text('Discord 연결 변경'),value:_changeDiscord,onChanged:_busy?null:(value)=>setState(()=>_changeDiscord=value==true)),
          if(_changeDiscord)TextFormField(key:const Key('company-discord-url'),controller:_webhook,enabled:!_busy,obscureText:true,autocorrect:false,enableSuggestions:false,
            decoration:const InputDecoration(labelText:'새 Discord 웹훅 주소',helperText:'비우고 저장하면 Discord 연결을 해제합니다.')),
          const Text('저장된 웹훅 주소는 표시하지 않습니다. 이미 발송한 메시지는 유지됩니다.',style:TextStyle(fontSize:12)),
          const Divider(height:32),TextButton.icon(key:const Key('company-settings-refresh'),onPressed:_busy?null:_load,icon:const Icon(Icons.refresh),label:const Text('최신 연결 설정 확인')),
        ],
        if(widget.owner&&_config!['ownerSetupUrl'] is String)TextButton(onPressed:_busy?null:_approve,child:const Text('Google 사진 저장 권한 승인')),
      ],
    ]))),
  ));
}
