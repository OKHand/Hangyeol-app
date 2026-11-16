import '../market/market_prices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'demo_store.dart';
import 'demo_erp_page.dart';
import 'demo_photos.dart';
export 'demo_erp_page.dart' show DemoErpPage;

class OfflineDemoApp extends StatelessWidget {
  const OfflineDemoApp({super.key,this.store});
  final DemoStore? store;
  @override
  Widget build(BuildContext context)=>MaterialApp(title:'한결씨드 체험',debugShowCheckedModeBanner:false,locale:const Locale('ko'),supportedLocales:const[Locale('ko')],localizationsDelegates:GlobalMaterialLocalizations.delegates,theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:demoGreen),scaffoldBackgroundColor:const Color(0xfff5f8f5),useMaterial3:true,inputDecorationTheme:const InputDecorationTheme(border:OutlineInputBorder(),isDense:true)),home:_DemoHome(initialStore:store));
}
class _DemoHome extends StatefulWidget {
  const _DemoHome({this.initialStore});
  final DemoStore? initialStore;
  @override
  State<_DemoHome> createState()=>_DemoHomeState();
}
class _DemoHomeState extends State<_DemoHome> {
  DemoStore? _store;
  String? _error;
  String _photoStatus='';
  int _tab=0;
  bool _picking=false;
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {setState(()=>_error=null);try{final store=widget.initialStore??await DemoStore.open();if(mounted){setState(()=>_store=store);}}catch(_){if(mounted){setState(()=>_error='기기에 저장된 체험 기록을 읽지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.');}}}
  void _changed(){if(mounted){setState((){});}}
  Future<void> _pick(ImageSource source) async {setState(()=>_picking=true);if(await demoPickPhoto(context,_store!,source)){_changed();}if(mounted){setState(()=>_picking=false);}}
  @override
  Widget build(BuildContext context){final store=_store;return Scaffold(appBar:AppBar(title:const Text('한결씨드',style:TextStyle(fontWeight:FontWeight.bold)),actions:const[Padding(padding:EdgeInsets.only(right:12),child:Chip(avatar:Icon(Icons.wifi_off,size:15),label:Text('오프라인 체험',style:TextStyle(fontSize:12))))]),body:SafeArea(child:store==null?Center(child:_error==null?const CircularProgressIndicator():Column(mainAxisSize:MainAxisSize.min,children:[Text(_error!),FilledButton(onPressed:_load,child:const Text('다시 시도'))])):Column(children:[Container(width:double.infinity,color:const Color(0xffe7efe9),padding:const EdgeInsets.symmetric(horizontal:14,vertical:6),child:const Text('체험 자료 · 실제 회사 원장과 별도 · 사진은 기기에 저장',style:TextStyle(fontSize:11,color:demoGreen))),Expanded(child:IndexedStack(index:_tab,children:[_home(store),DemoPhotosPage(store:store,onChanged:_changed,initialStatus:_photoStatus),const DemoErpPage(),_settings(store)]))])),bottomNavigationBar:NavigationBar(selectedIndex:_tab,onDestinationSelected:(v){FocusScope.of(context).unfocus();setState(()=>_tab=v);},destinations:const[NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'홈'),NavigationDestination(icon:Icon(Icons.photo_library_outlined),selectedIcon:Icon(Icons.photo_library),label:'작황 사진'),NavigationDestination(icon:Icon(Icons.table_chart_outlined),selectedIcon:Icon(Icons.table_chart),label:'ERP'),NavigationDestination(icon:Icon(Icons.more_horiz),label:'더보기')]));}
  Widget _home(DemoStore store)=>ListView(padding:const EdgeInsets.all(16),children:[
    const Text('안녕하세요, 체험 관리자님',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),const SizedBox(height:6),const Text('현장의 기록을 모으고, 필요한 업무를 바로 시작하세요.',style:TextStyle(fontSize:13,color:Color(0xff52685c))),const SizedBox(height:16),
    Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:const Color(0xffe2eddf),borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('FIELD NOTES',style:TextStyle(fontSize:11,letterSpacing:2,color:demoGreen)),const SizedBox(height:12),const Text('작물의 변화를\n사진 한 장에 담으세요.',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold,height:1.35)),const SizedBox(height:10),const Text('촬영일, 농가, 품종을 함께 기록하면\n필요할 때 더 쉽게 찾을 수 있습니다.'),const SizedBox(height:16),Wrap(spacing:8,children:[FilledButton.icon(onPressed:_picking?null:()=>_pick(ImageSource.camera),icon:const Icon(Icons.add_a_photo_outlined),label:const Text('사진 촬영')),OutlinedButton(onPressed:_picking?null:()=>_pick(ImageSource.gallery),child:const Text('사진 불러오기'))])])),const SizedBox(height:16),
    Row(children:[Expanded(child:_summary('저장한 사진','${store.photos.length}장',Icons.photo_library_outlined,()=>setState((){_photoStatus='';_tab=1;}))),const SizedBox(width:8),Expanded(child:_summary('정보 보완 필요','${store.photos.where((p)=>p.needsInfo).length}장',Icons.edit_note_outlined,()=>setState((){_photoStatus='needs_info';_tab=1;})))]),
    const SizedBox(height:8),Card(child:ListTile(leading:const Icon(Icons.show_chart,color:demoGreen),title:const Text('토마토 경매 시세'),subtitle:const Text('찰토마토 · 대추방울토마토 · 가상 자료 체험'),onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const MarketPricesPage())))),
    const SizedBox(height:8),Card(child:ListTile(leading:const Icon(Icons.inventory_2_outlined,color:demoGreen),title:const Text('ERP 업무 바로가기'),subtitle:const Text('입고·출고·통합·요약·집계·재고'),trailing:const Icon(Icons.arrow_forward),onTap:()=>setState(()=>_tab=2))),
    Card(child:ListTile(leading:const Icon(Icons.save_outlined,color:demoGreen),title:const Text('기기 저장 완료'),subtitle:const Text('외부 업로드는 하지 않습니다. 저장 기록과 연동 미리보기를 확인하세요.'),onTap:()=>setState(()=>_tab=3))),
    const SizedBox(height:16),Row(children:[const Expanded(child:Text('최근 기록',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),TextButton(onPressed:()=>setState((){_photoStatus='';_tab=1;}),child:const Text('전체 보기 →'))]),
    if(store.photos.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('첫 현장 기록을 남겨 보세요.')),
    ...store.photos.take(3).map((p)=>DemoPhotoCard(store:store,photo:p,onChanged:_changed)),
    const SizedBox(height:20),
  ]);
  Widget _summary(String label,String value,IconData icon,VoidCallback onTap)=>Card(margin:EdgeInsets.zero,child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(12),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:demoGreen),const SizedBox(height:10),Text(label,style:const TextStyle(fontSize:12)),const SizedBox(height:4),Text(value,style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold))]))));
  Widget _settings(DemoStore store)=>ListView(padding:const EdgeInsets.all(16),children:[
    const Text('더보기',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:12),const Card(child:ListTile(leading:CircleAvatar(child:Text('체')),title:Text('체험 관리자'),subtitle:Text('기기 내 체험 계정 · Google 로그인 불필요'))),
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('저장 진행 상태',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:10),Text('기기에 저장된 사진 ${store.photos.length}장'),const Text('외부 업로드 대기 0건 · 자동 전송 없음',style:TextStyle(fontSize:12,color:Color(0xff52685c))),const SizedBox(height:12),const Text('오프라인에서는 Google Sheets와 Discord에 실제로 보내지 않습니다. 아래에서 반영될 내용을 미리 보고 체험 작업 기록을 남길 수 있습니다.',style:TextStyle(fontSize:12,height:1.5)),const SizedBox(height:12),OutlinedButton.icon(onPressed:store.photos.isEmpty?null:()=>demoIntegrationPreview(context,store,store.photos.first,_changed),icon:const Icon(Icons.preview_outlined),label:const Text('사진 관리대장 · Discord 미리보기'))]))),
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('업무 연결',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const ListTile(contentPadding:EdgeInsets.zero,title:Text('Google Sheets 사진 관리대장'),subtitle:Text('오프라인 · 미리보기만 제공'),trailing:Icon(Icons.wifi_off)),const ListTile(contentPadding:EdgeInsets.zero,title:Text('Discord 사진 알림'),subtitle:Text('오프라인 · 미리보기만 제공'),trailing:Icon(Icons.wifi_off)),if(store.jobs.isEmpty)const Text('아직 체험 작업 기록이 없습니다.',style:TextStyle(fontSize:12)),...store.jobs.take(12).map((j)=>ListTile(contentPadding:EdgeInsets.zero,dense:true,leading:const Icon(Icons.preview_outlined),title:Text(j['type']=='sheets'?'사진 관리대장 체험':'Discord 알림 체험'),subtitle:Text('${j['title']} · ${j['message']}'),trailing:const Text('체험',style:TextStyle(fontSize:11,color:demoGreen))))]))),
    const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('체험 범위\n웹의 사진 등록·상세·수정·필터, 홈 요약, ERP 전체 검색 조건과 보고서 형식을 기기에서 체험합니다. 샘플 원장은 읽기 전용입니다. 회사 계정 로그인, 실제 시트 반영·Discord 전송은 온라인 연결이 필요합니다.\n\n실제 사진은 앱 전용 저장소에 보관합니다. 앱 삭제 시 체험 기록도 삭제됩니다. 기본 샘플 이미지는 실제 작황 사진이 아닌 삽화입니다.',style:TextStyle(fontSize:12,height:1.6)))),
    OutlinedButton.icon(onPressed:()=>_reset(store,true),icon:const Icon(Icons.restore),label:const Text('기본 샘플로 복원')),TextButton.icon(onPressed:()=>_reset(store,false),icon:const Icon(Icons.delete_outline),label:const Text('체험 사진과 기록 모두 지우기')),
  ]);
  Future<void> _reset(DemoStore store,bool samples) async {
    final result=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:Text(samples?'기본 샘플로 복원할까요?':'체험 기록을 모두 지울까요?'),content:const Text('이 앱에 저장한 사진 사본, 메모, 체험 작업 기록을 지웁니다. 갤러리 원본과 가상 ERP 원장은 바뀌지 않습니다.'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('진행'))]));
    if(result!=true){return;}
    try{await store.reset(restoreSamples:samples);if(mounted){setState((){_photoStatus='';});}}catch(_){if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('체험 기록을 초기화하지 못했습니다.')));}}
  }
}
