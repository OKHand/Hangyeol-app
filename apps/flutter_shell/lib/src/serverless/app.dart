import '../market/market_prices.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../demo/demo_erp.dart';
import '../demo/demo_erp_page.dart';
import 'client.dart';
import 'auth_browser.dart';
import 'photos.dart';
import 'company_connections.dart';
import 'app_updates.dart';
import 'photo_cache_settings.dart';
import 'industry_news.dart';
import 'news_discord_settings.dart';
import '../ui/hangyeol_theme.dart';
abstract class SessionVault {
  Future<String?> read(String key);
  Future<void> write(String key,String value);
  Future<void> delete(String key);
}
class SecureSessionVault implements SessionVault {
  final _storage=const FlutterSecureStorage(aOptions:AndroidOptions(encryptedSharedPreferences:true));
  @override
  Future<String?> read(String key)=>_storage.read(key:key);
  @override
  Future<void> write(String key,String value)=>_storage.write(key:key,value:value);
  @override
  Future<void> delete(String key)=>_storage.delete(key:key);
}
class ServerlessApp extends StatelessWidget {
  const ServerlessApp({super.key,required this.apiUrl,this.client,this.vault,this.launch,this.photoRepositoryFactory});
  final String apiUrl;
  final AppsScriptPlatformClient? client;
  final SessionVault? vault;
  final Future<bool> Function(Uri)? launch;
  final PhotoRepository Function(AppsScriptPlatformClient,String)? photoRepositoryFactory;
  @override
  Widget build(BuildContext context)=>MaterialApp(title:'한결씨드 온라인',debugShowCheckedModeBanner:false,locale:const Locale('ko'),supportedLocales:const[Locale('ko')],localizationsDelegates:GlobalMaterialLocalizations.delegates,theme:buildHangyeolTheme(),home:_AuthHome(apiUrl:apiUrl,client:client,vault:vault,launch:launch,photoRepositoryFactory:photoRepositoryFactory));
}
class _AuthHome extends StatefulWidget {
  const _AuthHome({required this.apiUrl,this.client,this.vault,this.launch,this.photoRepositoryFactory});
  final String apiUrl;
  final AppsScriptPlatformClient? client;
  final SessionVault? vault;
  final Future<bool> Function(Uri)? launch;
  final PhotoRepository Function(AppsScriptPlatformClient,String)? photoRepositoryFactory;
  @override
  State<_AuthHome> createState()=>_AuthHomeState();
}
class _AuthHomeState extends State<_AuthHome> with WidgetsBindingObserver {
  AppsScriptPlatformClient? _client;
  late SessionVault _vault;
  Map<String,dynamic>? _user;
  GoogleDeviceLogin? _attempt;
  Timer? _timer;
  bool _busy=false,_polling=false;
  String _error='';
  int _tab=0;
  int _photoSettingsRevision=0;
  PhotoRepository? _photoRepository;
  String? _photoRepositoryToken;
  bool _cacheOpening=false;
  PhotoRepository _photosFor(){
    if(_photoRepository==null||_photoRepositoryToken!=_client!.token){
      _photoRepository?.dispose();_photoRepositoryToken=_client!.token;
      _photoRepository=widget.photoRepositoryFactory?.call(_client!,_user!['email'] as String)??PhotoRepository(_client!,onAuthError:_handle);
    }return _photoRepository!;
  }
  void _closePhotos(){_photoRepository?.dispose();_photoRepository=null;_photoRepositoryToken=null;}
  Future<void> _openPhotoCache() async {
    if(_cacheOpening||_user==null){return;}
    _cacheOpening=true;final token=_client!.token;
    try{
      final repository=_photosFor();
      final directory=repository.cacheDirectory??Directory('${(await photoAccountDirectory(_client!,_user!['email'] as String)).path}/cache');
      if(!mounted||token!=_client!.token){return;}
      repository.cacheDirectory=directory;
      await showDialog<void>(context:context,builder:(_)=>PhotoCacheSettingsDialog(repository:repository));
    }catch(error){
      if(error is PlatformAuthFailure&&const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(error.code)){await _handle(error);}
      else if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('사진 캐시 정보를 열지 못했습니다. 다시 시도해 주세요.')));}
    }finally{_cacheOpening=false;}
  }
  final _visitedTabs=<int>{0};
  @override
  void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_vault=widget.vault??SecureSessionVault();try{_client=widget.client??AppsScriptPlatformClient(Uri.parse(widget.apiUrl));_restore();}catch(_){_error='회사 연결 주소가 설정되지 않은 빌드입니다.';}}
  Future<void> _restore() async {
    final client=_client!;setState(()=>_busy=true);
    try{client.token=await _vault.read(client.storageKey);if(client.token!=null){final user=await client.me();if(mounted){setState(()=>_user=user);}}}
    catch(error){await _handle(error);}
    finally{if(mounted){setState(()=>_busy=false);}}
  }
  Future<void> _handle(Object error) async {
    if(error is PlatformAuthFailure&&['AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'].contains(error.code)){
      _closePhotos();_client?.token=null;try{if(_client!=null){await _vault.delete(_client!.storageKey);}}catch(_){}
      if(mounted){setState((){_user=null;_attempt=null;_visitedTabs..clear()..add(0);});}
    }
    if(mounted){setState(()=>_error=error is PlatformAuthFailure?error.message:'기기의 로그인 정보를 처리하지 못했습니다. 다시 시도해 주세요.');}
  }
  Future<void> _start() async {
    if(_busy||_client==null){return;}
    setState((){_busy=true;_error='';});
    try{final attempt=await _client!.startLogin();if(!mounted){return;}setState(()=>_attempt=attempt);_timer?.cancel();_timer=Timer.periodic(const Duration(seconds:5),(_)=>_poll());await _openLogin(attempt);}
    catch(error){await _handle(error);}
    finally{if(mounted){setState(()=>_busy=false);}}
  }
  Future<void> _openLogin(GoogleDeviceLogin attempt) async {
    if(DateTime.now().isAfter(attempt.expiresAt)){_cancel();if(mounted){setState(()=>_error='로그인 요청이 만료되었습니다. 다시 시작해 주세요.');}return;}
    if(mounted){setState(()=>_error='');}
    try{final opened=await (widget.launch?.call(attempt.browserUrl)??openIsolatedLoginBrowser(attempt.browserUrl));if(!opened){throw PlatformAuthFailure('BROWSER_UNAVAILABLE','Google 로그인 창을 열지 못했습니다. “로그인 창 다시 열기”를 눌러 주세요.');}}
    catch(error){await _handle(error);}
  }
  Future<void> _poll() async {
    final attempt=_attempt;if(attempt==null||_polling||_client==null){return;}
    if(DateTime.now().isAfter(attempt.expiresAt)){_cancel();if(mounted){setState(()=>_error='로그인 요청이 만료되었습니다. 다시 시작해 주세요.');}return;}
    _polling=true;
    try{final user=await _client!.poll(attempt);if(!mounted||_attempt!=attempt){_client!.token=null;return;}if(user!=null){await _vault.write(_client!.storageKey,_client!.token!);_timer?.cancel();setState((){_user=user;_attempt=null;_tab=0;_visitedTabs..clear()..add(0);_error='';});}}
    catch(error){await _handle(error);if(error is PlatformAuthFailure&&['LOGIN_EXPIRED','ACCESS_DENIED'].contains(error.code)){_cancel();}}
    finally{_polling=false;}
  }
  void _cancel(){_timer?.cancel();if(mounted){setState(()=>_attempt=null);}}
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed){if(_attempt!=null){_poll();}else if(_user!=null){_refreshUser();}}}
  Future<void> _refreshUser() async {final token=_client!.token;try{final user=await _client!.me();if(mounted&&token==_client!.token){if(_user?['role']!=user['role']){_client!.invalidateReadCache();}setState(()=>_user=user);}}catch(error){if(token==_client!.token){await _handle(error);}}}
  Future<DemoReport> _report(DemoQuery query) async {final token=_client!.token;try{return await _client!.report(query);}catch(error){if(token==_client!.token){await _handle(error);}rethrow;}}
  Future<Map<String,List<String>>> _suggestions() async {final token=_client!.token;try{return await _client!.suggestions();}catch(error){if(token==_client!.token){await _handle(error);}rethrow;}}
  Future<Map<String,List<String>>> _refreshSuggestions() async {_client!.invalidateReadCache();return _suggestions();}
  Future<void> _logout() async {
    if(_busy){return;}setState(()=>_busy=true);
    try{await _client!.logout();_closePhotos();if(mounted){setState((){_user=null;_error='';_tab=0;_visitedTabs..clear()..add(0);});}await _vault.delete(_client!.storageKey);}
    catch(error){await _handle(error);}
    finally{if(mounted){setState(()=>_busy=false);}}
  }
  @override
  void dispose(){WidgetsBinding.instance.removeObserver(this);_timer?.cancel();_closePhotos();if(widget.client==null){_client?.close();}super.dispose();}
  @override
  Widget build(BuildContext context){
    final user=_user;
    final attempt=_attempt;
    if(user==null){return Scaffold(appBar:AppBar(title:const Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.eco,size:20,color:Color(0xff1e6247)),SizedBox(width:6),Text('한결씨드 온라인')])),body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.eco,size:56,color:Color(0xff1e6247)),const SizedBox(height:18),const Text('회사 Google 계정으로 로그인',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold),textAlign:TextAlign.center),const SizedBox(height:12),const Text('관리자가 등록한 직원만 사용할 수 있습니다. Google 로그인은 계정이 분리된 브라우저 창에서 진행됩니다.',textAlign:TextAlign.center),const SizedBox(height:20),
      if(attempt!=null)...[const Text('브라우저에서 회사 Google 계정을 확인하고\n아래 2자리 번호를 눌러 승인해 주세요.',textAlign:TextAlign.center),const SizedBox(height:12),Container(key:const Key('login-match-code'),padding:const EdgeInsets.symmetric(vertical:12),decoration:BoxDecoration(color:const Color(0xffe7efe9),borderRadius:BorderRadius.circular(12)),child:SelectableText(attempt.userCode,textAlign:TextAlign.center,style:const TextStyle(fontSize:36,fontWeight:FontWeight.bold,letterSpacing:6,color:Color(0xff1e6247)))),const SizedBox(height:8),const Text('번호를 직접 입력할 필요 없이 같은 숫자 버튼을 누른 뒤\n앱으로 돌아오면 연결됩니다.',textAlign:TextAlign.center),const SizedBox(height:16),FilledButton(onPressed:_poll,child:const Text('로그인 확인')),TextButton(onPressed:()=>_openLogin(attempt),child:const Text('로그인 창 다시 열기')),TextButton(onPressed:_cancel,child:const Text('로그인 취소')),ExpansionTile(tilePadding:EdgeInsets.zero,title:const Text('로그인 화면이 열리지 않나요?',style:TextStyle(fontSize:14)),children:[const Text('“현재 파일을 열 수 없습니다”가 나오면 Chrome을 최신 버전으로 업데이트한 뒤 다시 시도하거나, 주소를 복사해 Chrome 시크릿·Edge InPrivate·삼성 인터넷 비밀 모드에서 여세요. 회사 Google 계정 하나로 로그인한 뒤 위 2자리 번호를 눌러 주세요.',style:TextStyle(fontSize:13)),TextButton.icon(key:const Key('copy-google-login-url'),onPressed:()async{await Clipboard.setData(ClipboardData(text:attempt.url.toString()));if(context.mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('로그인 주소를 복사했습니다. 다른 브라우저에서 열어 주세요.')));}},icon:const Icon(Icons.copy_outlined),label:const Text('로그인 주소 복사'))])]
      else FilledButton.icon(key:const Key('google-login'),onPressed:_busy||_client==null?null:_start,icon:const Icon(Icons.login),label:Text(_busy?'확인 중…':'Google 로그인')),
      if(_error.isNotEmpty)...[const SizedBox(height:16),Text(_error,textAlign:TextAlign.center,style:TextStyle(color:Theme.of(context).colorScheme.error))],
    ]))))));}
    final manage=(user['permissions'] as List? ?? []).contains('staff.manage');
    final roleLabel=const {'owner':'최초 관리자','admin':'관리자','member':'직원','viewer':'조회자'}[user['role']]??'${user['role']??''}';
    return Scaffold(appBar:AppBar(title:const Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.eco,size:20,color:kHangyeolPrimary),SizedBox(width:6),Text('한결씨드 온라인')]),actions:[IconButton(tooltip:'계정·권한 새로 확인',onPressed:_refreshUser,icon:const Icon(Icons.refresh)),IconButton(tooltip:'로그아웃',onPressed:_busy?null:_logout,icon:const Icon(Icons.logout))]),body:SafeArea(child:Column(children:[Container(width:double.infinity,decoration:const BoxDecoration(color:kHangyeolCanvas,border:Border(bottom:BorderSide(color:kHangyeolDivider,width:0.8))),padding:const EdgeInsets.symmetric(horizontal:14,vertical:6),child:Text('${user['email']} · $roleLabel',style:const TextStyle(fontSize:12,color:kHangyeolMuted))),if(_error.isNotEmpty)Padding(padding:const EdgeInsets.all(6),child:Text(_error,style:TextStyle(color:Theme.of(context).colorScheme.error))),Expanded(child:IndexedStack(index:_tab,children:[
      DemoErpPage(key:ValueKey('erp-${user['email']}'),loadReport:_report,loadSuggestions:_suggestions,refreshSuggestions:_refreshSuggestions),
      _visitedTabs.contains(1)?OnlinePhotosPage(key:ValueKey('photos-${user['email']}'),client:_client!,email:user['email'] as String,canCreate:(user['permissions'] as List? ?? []).contains('photos.create'),owner:user['role']=='owner',canManage:manage,onAuthError:_handle,settingsRevision:_photoSettingsRevision,repository:_photosFor(),useAccountStorage:true):const SizedBox.shrink(),
      _visitedTabs.contains(2)?MarketPricesPage(key:ValueKey('market-${user['email']}'),client:_client!,onAuthError:_handle,canManage:manage,email:'${user['email']??''}'):const SizedBox.shrink(),
      _visitedTabs.contains(3)?IndustryNewsPage(key:ValueKey('news-${user['email']}'),client:_client!,onAuthError:_handle,email:'${user['email']??''}'):const SizedBox.shrink(),
      _visitedTabs.contains(4)?_SettingsPage(client:_client!,user:user,manage:manage,onAuthError:_handle,onPhotoCache:_openPhotoCache,onConnectionsChanged:(){if(mounted){setState(()=>_photoSettingsRevision++);}}):const SizedBox.shrink(),
    ]))])),bottomNavigationBar:DecoratedBox(decoration:const BoxDecoration(color:kHangyeolCanvas,border:Border(top:BorderSide(color:kHangyeolDivider,width:0.8))),child:NavigationBar(height:58,selectedIndex:_tab,onDestinationSelected:(value){FocusScope.of(context).unfocus();setState((){_visitedTabs.add(value);_tab=value;});},destinations:const [NavigationDestination(icon:Icon(Icons.table_chart_outlined),selectedIcon:Icon(Icons.table_chart),label:'ERP'),NavigationDestination(icon:Icon(Icons.photo_library_outlined),selectedIcon:Icon(Icons.photo_library),label:'작황 사진'),NavigationDestination(key:Key('open-market-prices'),icon:Icon(Icons.show_chart),selectedIcon:Icon(Icons.show_chart),label:'농산물 시세'),NavigationDestination(key:Key('open-industry-news'),icon:Icon(Icons.newspaper_outlined),selectedIcon:Icon(Icons.newspaper),label:'업계 뉴스'),NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings),label:'설정')])));
  }
}
class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.client,required this.user,required this.manage,required this.onAuthError,required this.onPhotoCache,required this.onConnectionsChanged});
  final AppsScriptPlatformClient client;
  final Map<String,dynamic> user;
  final bool manage;
  final Future<void> Function(Object) onAuthError;
  final VoidCallback onConnectionsChanged;
  final Future<void> Function() onPhotoCache;

  Widget _tile({Key? tileKey,required IconData icon,required String title,required String subtitle,required VoidCallback onTap})=>ListTile(
    key:tileKey,
    dense:true,
    visualDensity:VisualDensity.compact,
    contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:3),
    leading:Icon(icon,size:22,color:kHangyeolInk),
    title:Text(title,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w500,color:kHangyeolInk)),
    subtitle:Text(subtitle,style:const TextStyle(fontSize:12,color:kHangyeolMuted)),
    trailing:const Icon(Icons.chevron_right,size:18,color:kHangyeolSubtle),
    onTap:onTap,
  );

  Widget _menuSection(String heading,List<Widget> items){
    final spaced=<Widget>[];
    for(var i=0;i<items.length;i++){
      if(i>0){spaced.add(const Divider(height:1,indent:56,color:kHangyeolDivider));}
      spaced.add(items[i]);
    }
    return Container(
      color:kHangyeolCanvas,
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Padding(padding:const EdgeInsets.fromLTRB(16,12,16,4),child:Text(heading,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:kHangyeolMuted))),
        ...spaced,
      ]),
    );
  }

  @override
  Widget build(BuildContext context){
    final roleLabel=const {'owner':'최초 관리자','admin':'관리자','member':'직원','viewer':'조회자'}[user['role']]??'${user['role']??''}';
    return ColoredBox(
      color:kHangyeolCanvas,
      child:Align(
        alignment:Alignment.topCenter,
        child:ConstrainedBox(
          constraints:const BoxConstraints(maxWidth:680),
          child:ListView(padding:const EdgeInsets.only(bottom:24),children:[
            Container(
              color:kHangyeolCanvas,
              padding:const EdgeInsets.fromLTRB(16,14,16,16),
              child:Row(children:[
                Container(
                  width:48,
                  height:48,
                  decoration:const BoxDecoration(color:kHangyeolTint,shape:BoxShape.circle),
                  child:const Icon(Icons.person,color:kHangyeolPrimary,size:26),
                ),
                const SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(user['name'] as String? ?? '내 계정',overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w700,color:kHangyeolInk)),
                  const SizedBox(height:2),
                  Text(user['email'] as String,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:13,color:kHangyeolMuted)),
                ])),
                const SizedBox(width:8),
                Container(
                  padding:const EdgeInsets.symmetric(horizontal:12,vertical:5),
                  decoration:BoxDecoration(color:kHangyeolCanvas,borderRadius:BorderRadius.circular(999),border:Border.all(color:kHangyeolBorder)),
                  child:Text(roleLabel,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:kHangyeolPrimary)),
                ),
              ]),
            ),
            Container(height:8,color:kHangyeolSurface),
            _menuSection('앱 · 기기 관리',[
              _tile(
                tileKey:const Key('settings-app-update'),
                icon:Icons.system_update_outlined,
                title:'앱 업데이트',
                subtitle:'이 기기에 맞는 최신 설치 파일 확인',
                onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>AppUpdatePage(client:client,onAuthError:onAuthError,googleEmail:user['email'] as String))),
              ),
              _tile(
                tileKey:const Key('settings-photo-cache'),
                icon:Icons.cleaning_services_outlined,
                title:'사진 캐시 파일 삭제',
                subtitle:'이 기기의 미리보기·열어본 사진 임시 파일 관리',
                onTap:onPhotoCache,
              ),
            ]),
            if(manage)...[
              const SizedBox(height:4),
              Container(height:8,color:kHangyeolSurface),
              _menuSection('관리자 설정',[
                _tile(
                  tileKey:const Key('settings-company-connections'),
                  icon:Icons.cloud_outlined,
                  title:'사진 저장소·Discord 연결',
                  subtitle:'새 사진 저장 폴더와 알림 연결 관리',
                  onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>CompanyConnectionsPage(client:client,owner:user['role']=='owner',onAuthError:onAuthError,onChanged:onConnectionsChanged))),
                ),
                _tile(
                  tileKey:const Key('settings-news-discord'),
                  icon:Icons.newspaper_outlined,
                  title:'업계 뉴스 Discord 알림',
                  subtitle:'매주 월요일 오전 10시 주간 브리핑 웹훅 설정',
                  onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>NewsDiscordSettingsPage(client:client,onAuthError:onAuthError))),
                ),
                _tile(
                  tileKey:const Key('settings-staff'),
                  icon:Icons.manage_accounts_outlined,
                  title:'직원·권한 관리',
                  subtitle:'등록된 직원 계정 및 역할 관리',
                  onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>Scaffold(appBar:AppBar(title:const Text('직원·권한 관리')),body:_StaffPage(client:client,owner:user['role']=='owner')))),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
class _StaffPage extends StatefulWidget {
  const _StaffPage({required this.client,required this.owner});
  final AppsScriptPlatformClient client;
  final bool owner;
  @override
  State<_StaffPage> createState()=>_StaffPageState();
}
class _StaffPageState extends State<_StaffPage> {
  List<Map<String,dynamic>> _users=[];
  String _error='';bool _busy=false;
  @override
  void initState(){super.initState();_load();}
  Future<void> _load()async{setState(()=>_busy=true);try{final users=await widget.client.users();if(mounted){setState(()=>_users=users);}}catch(error){if(mounted){setState(()=>_error=error.toString());}}finally{if(mounted){setState(()=>_busy=false);}}}
  Future<void> _edit([Map<String,dynamic>? user])async{
    final email=TextEditingController(text:user?['email'] as String? ?? ''),name=TextEditingController(text:user?['name'] as String? ?? '');
    var role=user?['role'] as String? ?? 'viewer',active=user?['active'] as bool? ?? true;
    final result=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(context,change)=>AlertDialog(title:Text(user==null?'직원 등록':'직원 권한 변경'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:email,readOnly:user!=null,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Google 이메일')),const SizedBox(height:12),TextField(controller:name,maxLength:100,decoration:const InputDecoration(labelText:'이름')),const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:role,items:[const DropdownMenuItem(value:'viewer',child:Text('조회자')),const DropdownMenuItem(value:'member',child:Text('직원')),if(widget.owner)const DropdownMenuItem(value:'admin',child:Text('관리자'))],onChanged:(v)=>change(()=>role=v!)),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('계정 활성화'),value:active,onChanged:(v)=>change(()=>active=v)),const Text('권한 변경과 비활성화는 다음 서버 요청부터 적용됩니다.',style:TextStyle(fontSize:12))])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('저장'))])));
    if(result==true){try{await widget.client.saveUser(email:email.text,name:name.text,role:role,active:active);if(mounted){setState(()=>_error='');await _load();}}catch(error){if(mounted){setState(()=>_error=error.toString());}}}
    email.dispose();name.dispose();
  }
  @override
  Widget build(BuildContext context)=>ColoredBox(
    color:kHangyeolCanvas,
    child:ListView(padding:const EdgeInsets.fromLTRB(16,12,16,20),children:[
      const Text('직원·권한',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700,color:kHangyeolInk)),
      const SizedBox(height:6),
      const Text('사용할 Google 이메일을 먼저 등록하세요. 원본 시트를 직원에게 직접 공유할 필요는 없습니다.',style:TextStyle(fontSize:12,color:kHangyeolMuted)),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:_busy?null:()=>_edit(),icon:const Icon(Icons.person_add_alt),label:const Text('직원 등록')),
      if(_busy)const Padding(padding:EdgeInsets.only(top:8),child:LinearProgressIndicator()),
      if(_error.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Text(_error,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      const SizedBox(height:8),
      for(final u in _users)...[
        const Divider(height:1,color:kHangyeolDivider),
        ListTile(
          contentPadding:const EdgeInsets.symmetric(horizontal:4,vertical:2),
          title:Text(u['name'] as String,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600,color:kHangyeolInk)),
          subtitle:Text('${u['email']}\n${u['role']} · ${u['active']==true?'활성':'비활성'}',style:const TextStyle(fontSize:12,color:kHangyeolMuted)),
          trailing:u['role']=='owner'||!widget.owner&&u['role']=='admin'?const Icon(Icons.lock_outline,color:kHangyeolSubtle):IconButton(tooltip:'권한 변경',onPressed:()=>_edit(u),icon:const Icon(Icons.edit_outlined)),
        ),
      ],
    ]),
  );
}
