import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'client.dart';

class NewsDiscordSettingsPage extends StatefulWidget {
  const NewsDiscordSettingsPage({super.key,required this.client,required this.onAuthError});
  final AppsScriptPlatformClient client;
  final Future<void> Function(Object) onAuthError;
  @override
  State<NewsDiscordSettingsPage> createState()=>_NewsDiscordSettingsPageState();
}

class _NewsDiscordSettingsPageState extends State<NewsDiscordSettingsPage> {
  final _webhook=TextEditingController();
  Map<String,dynamic>? _settings;
  bool _busy=false;
  bool _changeWebhook=false;
  bool _weeklyEnabled=false;
  String _error='';

  @override
  void initState(){
    super.initState();
    _load();
  }

  @override
  void dispose(){
    _webhook.dispose();
    super.dispose();
  }

  Future<void> _fail(Object error) async {
    if(error is PlatformAuthFailure&&const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(error.code)){
      await widget.onAuthError(error);
    }
    if(mounted){
      setState(()=>_error=error is PlatformAuthFailure?error.message:'뉴스 Discord 설정을 처리하지 못했습니다.');
    }
  }

  Future<void> _load() async {
    setState((){_busy=true;_error='';});
    try{
      final data=await widget.client.call('news.settings');
      if(!mounted){return;}
      setState((){
        _settings=data;
        _weeklyEnabled=data['weeklyEnabled']==true;
      });
    }catch(error){
      await _fail(error);
    }finally{
      if(mounted){setState(()=>_busy=false);}
    }
  }

  Future<void> _save() async {
    if(_busy||_settings==null){return;}
    setState((){_busy=true;_error='';});
    try{
      final data=await widget.client.call('news.configure',params:{
        'expectedVersion':_settings!['settingsVersion'],
        if(_changeWebhook)'webhook':_webhook.text.trim(),
        'weeklyEnabled':_weeklyEnabled,
      });
      if(!mounted){return;}
      setState((){
        _settings=data;
        _weeklyEnabled=data['weeklyEnabled']==true;
        _changeWebhook=false;
      });
      _webhook.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('업계 뉴스 Discord 알림 설정을 저장했습니다.')));
    }catch(error){
      await _fail(error);
    }finally{
      if(mounted){setState(()=>_busy=false);}
    }
  }

  Future<void> _sendNow() async {
    if(_busy){return;}
    setState((){_busy=true;_error='';});
    try{
      final res=await widget.client.call('news.sendWeekly',params:{});
      if(!mounted){return;}
      final count=(res['count'] as num?)?.toInt()??0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(count>0?'주간 브리핑 $count건을 Discord로 발송했습니다.':'최근 7일간 발송할 기사가 없어 안내 메시지를 보냈습니다.')));
      await _load();
    }catch(error){
      await _fail(error);
    }finally{
      if(mounted){setState(()=>_busy=false);}
    }
  }

  String _formatKst(String iso){
    final dt=DateTime.tryParse(iso)?.toUtc().add(const Duration(hours:9));
    if(dt==null){return '발송 기록 없음';}
    final mm=dt.month.toString().padLeft(2,'0');
    final dd=dt.day.toString().padLeft(2,'0');
    final hh=dt.hour.toString().padLeft(2,'0');
    final min=dt.minute.toString().padLeft(2,'0');
    return '${dt.year}-$mm-$dd $hh:$min KST';
  }

  @override
  Widget build(BuildContext context){
    final s=_settings;
    final configured=s?['webhookConfigured']==true;
    final sheetUrl='${s?['sheetUrl']??''}';
    return PopScope(
      canPop:!_busy,
      child:Scaffold(
        appBar:AppBar(
          title:const Text('업계 뉴스 Discord 알림'),
          actions:[
            TextButton(
              key:const Key('news-discord-save'),
              onPressed:_busy||s==null?null:_save,
              child:const Text('저장'),
            ),
          ],
        ),
        body:SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[
          const Text('관리자만 설정할 수 있습니다. 저장된 웹훅 주소는 보안상 다시 표시하지 않습니다.',style:TextStyle(fontSize:13)),
          if(_busy)const Padding(padding:EdgeInsets.only(top:8),child:LinearProgressIndicator()),
          if(_error.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(_error,style:TextStyle(color:Theme.of(context).colorScheme.error))),
          if(s!=null)...[
            const SizedBox(height:16),
            const Text('Discord 웹훅 연결 상태',style:TextStyle(fontWeight:FontWeight.bold)),
            const SizedBox(height:4),
            Text(configured?'연결됨':'미연결',key:const Key('news-discord-status')),
            CheckboxListTile(
              key:const Key('news-change-webhook'),
              contentPadding:EdgeInsets.zero,
              title:const Text('Discord 웹훅 주소 입력/변경'),
              value:_changeWebhook,
              onChanged:_busy?null:(v)=>setState(()=>_changeWebhook=v==true),
            ),
            if(_changeWebhook)TextFormField(
              key:const Key('news-discord-webhook-input'),
              controller:_webhook,
              enabled:!_busy,
              autocorrect:false,
              enableSuggestions:false,
              decoration:const InputDecoration(
                labelText:'Discord 웹훅 주소',
                hintText:'https://discord.com/api/webhooks/...',
                helperText:'비우고 저장하면 웹훅 연결을 해제합니다.',
              ),
            ),
            const Divider(height:28),
            SwitchListTile(
              key:const Key('news-weekly-switch'),
              contentPadding:EdgeInsets.zero,
              title:const Text('매주 월요일 오전 10시 자동 일괄 발송'),
              subtitle:Text('${s['scheduleLabel']??'매주 월요일 오전 10시 (KST)'} · 최근 7일간의 주요 기사를 한 번에 보냅니다.'),
              value:_weeklyEnabled,
              onChanged:_busy?null:(v)=>setState(()=>_weeklyEnabled=v),
            ),
            const SizedBox(height:8),
            Text('마지막 주간 발송: ${_formatKst('${s['lastSentAt']??''}')}${configured&&s['lastSentAt']!=''?' (${s['lastSentCount']}건)':''}',style:const TextStyle(fontSize:12,color:Color(0xff52685c))),
            const SizedBox(height:16),
            FilledButton.tonalIcon(
              key:const Key('news-discord-test-send'),
              onPressed:_busy||!configured?null:_sendNow,
              icon:const Icon(Icons.send_outlined),
              label:const Text('지금 주간 브리핑 즉시 발송'),
            ),
            const Divider(height:28),
            if(sheetUrl.isNotEmpty)TextButton.icon(
              onPressed:() async {
                final uri=Uri.tryParse(sheetUrl);
                if(uri!=null){await launchUrl(uri,mode:LaunchMode.externalApplication);}
              },
              icon:const Icon(Icons.table_view_outlined),
              label:const Text('한결씨드 업계 뉴스 관리대장 열기'),
            ),
            TextButton.icon(
              onPressed:_busy?null:_load,
              icon:const Icon(Icons.refresh),
              label:const Text('최신 설정 새로고침'),
            ),
          ],
        ])),
      ),
    );
  }
}
