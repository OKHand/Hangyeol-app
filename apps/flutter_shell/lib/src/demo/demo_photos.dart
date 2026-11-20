import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'demo_store.dart';
import 'demo_photo_metadata.dart';

String demoKoreanTimestamp(String raw) { final parsed=DateTime.tryParse(raw); if(parsed==null){return raw;} final k=parsed.toUtc().add(const Duration(hours:9));return '${demoDay(k)} ${k.hour.toString().padLeft(2,'0')}:${k.minute.toString().padLeft(2,'0')} (한국 시간)'; }

class DemoPhotoImage extends StatelessWidget {
  const DemoPhotoImage({super.key,required this.photo,required this.store,this.height=180,this.fit=BoxFit.cover});
  final DemoPhoto photo;
  final DemoStore store;
  final double height;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius:BorderRadius.circular(12),child:photo.isSample?SizedBox(height:height,width:double.infinity,child:CustomPaint(painter:_PlantPainter(photo.fileName),child:const Align(alignment:Alignment.bottomRight,child:Padding(padding:EdgeInsets.all(10),child:Text('체험 삽화',style:TextStyle(fontSize:11,color:Color(0xff52685c))))))):Image.file(store.photoFile(photo),cacheWidth:1600,height:height,width:double.infinity,fit:fit,errorBuilder:(context,error,stack)=>SizedBox(height:height,child:const Center(child:Text('사진 파일을 찾을 수 없습니다')))));
}
class _PlantPainter extends CustomPainter {
  _PlantPainter(this.kind);
  final String kind;
  @override
  void paint(Canvas canvas,Size size) {
    canvas.drawRect(Offset.zero&size,Paint()..color=const Color(0xffe3eee2));
    canvas.drawRect(Rect.fromLTWH(0,size.height*.8,size.width,size.height*.2),Paint()..color=const Color(0xffd1bda2));
    final stem=Paint()..color=const Color(0xff3d7353)..strokeWidth=5..style=PaintingStyle.stroke;
    for (var plant=0;plant<3;plant++) {
      final x=size.width*(plant+1)/4;
      canvas.drawLine(Offset(x,size.height*.83),Offset(x,size.height*.2),stem);
      for (var i=0;i<4;i++) {
        final y=size.height*(.28+i*.13),direction=i.isEven?1.0:-1.0;
        canvas.save();canvas.translate(x,y);canvas.rotate(direction*.5);
        canvas.drawOval(Rect.fromCenter(center:Offset(direction*18,0),width:42,height:17),Paint()..color=const Color(0xff70a16a));canvas.restore();
        final fruit=Paint()..color=kind=='sample-tomato'?const Color(0xffb45b45):kind=='sample-pepper'?const Color(0xff7c9d4c):const Color(0xff52846a);
        final at=Offset(x-direction*16,y+16);
        if (kind=='sample-tomato') { canvas.drawCircle(at,9,fruit); }
        else { canvas.save();canvas.translate(at.dx,at.dy);canvas.rotate(math.pi*.12);canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5,-5,10,28),const Radius.circular(6)),fruit);canvas.restore(); }
      }
    }
  }
  @override
  bool shouldRepaint(covariant _PlantPainter oldDelegate)=>oldDelegate.kind!=kind;
}
Future<bool> demoPickPhoto(BuildContext context,DemoStore store,ImageSource source) async {
  try {
    final selected=await ImagePicker().pickImage(source:source);
    if (selected==null||!context.mounted) { return false; }
    final file=File(selected.path);
    final metadata=await DemoPhotoMetadata.read(file,camera:source==ImageSource.camera);
    if (!context.mounted) { return false; }
    return await Navigator.of(context).push<bool>(MaterialPageRoute(builder:(_)=>DemoPhotoEditor(store:store,source:file,metadata:metadata)))??false;
  } catch (_) { if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('사진을 열지 못했습니다. 카메라 권한이나 갤러리를 확인해 주세요.'))); } return false; }
}
class DemoPhotosPage extends StatefulWidget {
  const DemoPhotosPage({super.key,required this.store,required this.onChanged,this.initialStatus=''});
  final DemoStore store;
  final VoidCallback onChanged;
  final String initialStatus;
  @override
  State<DemoPhotosPage> createState()=>_DemoPhotosPageState();
}
class _DemoPhotosPageState extends State<DemoPhotosPage> {
  final _farm=TextEditingController(),_crop=TextEditingController(),_region=TextEditingController(),_query=TextEditingController();
  String _status='',_basis='captured',_error='';
  DateTime? _start,_end;
  DemoPhotoFilter _applied=const DemoPhotoFilter();
  int _limit=12;
  bool _picking=false;
  @override
  void initState(){super.initState();_status=widget.initialStatus;_applied=DemoPhotoFilter(status:_status);}
  @override
  void didUpdateWidget(covariant DemoPhotosPage oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.initialStatus!=widget.initialStatus) { _status=widget.initialStatus;_apply(); } }
  @override
  void dispose(){_farm.dispose();_crop.dispose();_region.dispose();_query.dispose();super.dispose();}
  void _apply(){if (_start!=null&&_end!=null&&_start!.isAfter(_end!)) { setState(()=>_error='시작일이 종료일보다 늦습니다.');return; }setState((){_error='';_limit=12;_applied=DemoPhotoFilter(farm:_farm.text,crop:_crop.text,region:_region.text,query:_query.text,status:_status,dateBasis:_basis,start:_start,end:_end);});}
  void _reset(){_farm.clear();_crop.clear();_region.clear();_query.clear();_status='';_basis='captured';_start=null;_end=null;_apply();}
  Future<void> _pick(ImageSource source) async {setState(()=>_picking=true);if (await demoPickPhoto(context,widget.store,source)) {widget.onChanged();}if(mounted){setState(()=>_picking=false);}}
  Future<void> _date(bool start) async { final date=await showDatePicker(context:context,initialDate:(start?_start:_end)??DateTime(2026,11,start?1:10),firstDate:DateTime(1970),lastDate:DateTime(2100));if(date!=null&&mounted){setState((){if(start){_start=date;}else{_end=date;}});} }
  @override
  Widget build(BuildContext context){
    final photos=widget.store.photos.where(_applied.matches).toList();
    return ListView(padding:const EdgeInsets.all(14),children:[
      const Text('작황 사진',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:4),const Text('농가와 작물의 변화를 차곡차곡 살펴보세요.',style:TextStyle(fontSize:12,color:Color(0xff52685c))),const SizedBox(height:12),
      Wrap(spacing:8,children:[FilledButton.icon(onPressed:_picking?null:()=>_pick(ImageSource.camera),icon:const Icon(Icons.photo_camera_outlined),label:const Text('사진 촬영')),OutlinedButton.icon(onPressed:_picking?null:()=>_pick(ImageSource.gallery),icon:const Icon(Icons.photo_library_outlined),label:const Text('사진 불러오기'))]),const SizedBox(height:12),
      Card(margin:EdgeInsets.zero,child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
        TextField(key:const Key('photo-farm'),controller:_farm,decoration:const InputDecoration(labelText:'농가명',hintText:'농가명 일부로 조회')),const SizedBox(height:10),
        Row(children:[Expanded(child:TextField(key:const Key('photo-crop'),controller:_crop,decoration:const InputDecoration(labelText:'작물',hintText:'예: 토마토'))),const SizedBox(width:8),Expanded(child:TextField(controller:_region,decoration:const InputDecoration(labelText:'지역',hintText:'주소 일부')))]),const SizedBox(height:10),
        TextField(controller:_query,decoration:const InputDecoration(labelText:'품종 · 제목 · 메모 검색',prefixIcon:Icon(Icons.search))),const SizedBox(height:12),
        Row(children:[Expanded(child:DropdownButtonFormField<String>(key:ValueKey('basis-$_basis'),initialValue:_basis,decoration:const InputDecoration(labelText:'날짜 기준'),items:const[DropdownMenuItem(value:'captured',child:Text('촬영일')),DropdownMenuItem(value:'created',child:Text('등록일'))],onChanged:(v)=>setState(()=>_basis=v!))),const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(key:ValueKey('status-$_status'),initialValue:_status,decoration:const InputDecoration(labelText:'정보 상태'),isExpanded:true,items:const[DropdownMenuItem(value:'',child:Text('전체')),DropdownMenuItem(value:'needs_info',child:Text('보완 필요')),DropdownMenuItem(value:'ready',child:Text('입력 완료'))],onChanged:(v)=>setState(()=>_status=v!)))]),const SizedBox(height:10),
        Row(children:[Expanded(child:OutlinedButton(onPressed:()=>_date(true),child:Text(_start==null?'시작일 전체':demoDay(_start!),style:const TextStyle(fontSize:12)))),const Padding(padding:EdgeInsets.symmetric(horizontal:6),child:Text('~')),Expanded(child:OutlinedButton(onPressed:()=>_date(false),child:Text(_end==null?'종료일 전체':demoDay(_end!),style:const TextStyle(fontSize:12))))]),
        if(_start!=null||_end!=null) Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>setState((){_start=null;_end=null;}),child:const Text('기간 해제'))),
        if(_error.isNotEmpty) Text(_error,style:TextStyle(color:Theme.of(context).colorScheme.error)),
        Row(children:[TextButton(onPressed:_reset,child:const Text('초기화')),const Spacer(),FilledButton(key:const Key('photo-search'),onPressed:_apply,child:const Text('조회'))]),
      ]))),
      Row(children:[Expanded(child:Text('${photos.length}장의 사진',style:const TextStyle(fontSize:12))),TextButton.icon(onPressed:()async{try{await widget.store.load();if(mounted){widget.onChanged();_apply();}}catch(_){if(mounted){setState(()=>_error='기기 저장 자료를 읽지 못했습니다.');}}},icon:const Icon(Icons.refresh,size:16),label:const Text('새로고침'))]),
      if(photos.isEmpty) const Padding(padding:EdgeInsets.all(30),child:Text('조회된 사진이 없습니다.\n새 사진을 등록하거나 검색 조건을 바꿔 보세요.',textAlign:TextAlign.center)),
      ...photos.take(_limit).map((p)=>DemoPhotoCard(store:widget.store,photo:p,onChanged:widget.onChanged)),
      if(photos.length>_limit) OutlinedButton(onPressed:()=>setState(()=>_limit+=12),child:const Text('사진 더 보기')),
      const SizedBox(height:20),
    ]);
  }
}
class DemoPhotoCard extends StatelessWidget {
  const DemoPhotoCard({super.key,required this.store,required this.photo,required this.onChanged});
  final DemoStore store;
  final DemoPhoto photo;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context)=>Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:()async{await Navigator.of(context).push<void>(MaterialPageRoute(builder:(_)=>DemoPhotoDetail(store:store,photoId:photo.id,onChanged:onChanged)));},child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[DemoPhotoImage(photo:photo,store:store),Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(photo.farmName.isEmpty?'농가를 입력해 주세요':photo.farmName,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))),_Status(photo:photo)]),const SizedBox(height:5),Text([photo.crop,photo.variety].where((v)=>v.isNotEmpty).join(' · ')),const SizedBox(height:5),Text('${photo.date.isEmpty?'촬영일 미입력':photo.date} · ${photo.location.isEmpty?'주소 미입력':photo.location}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,color:Color(0xff52685c))),if(photo.note.isNotEmpty)...[const SizedBox(height:6),Text(photo.note,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12))]]))])));
}
class _Status extends StatelessWidget {
  const _Status({required this.photo});
  final DemoPhoto photo;
  @override
  Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),decoration:BoxDecoration(color:photo.needsInfo?const Color(0xfff2eadb):const Color(0xffe3eee2),borderRadius:BorderRadius.circular(6)),child:Text(photo.needsInfo?'보완 필요':'입력 완료',style:const TextStyle(fontSize:11)));
}
class DemoPhotoDetail extends StatefulWidget {
  const DemoPhotoDetail({super.key,required this.store,required this.photoId,required this.onChanged});
  final DemoStore store;
  final String photoId;
  final VoidCallback onChanged;
  @override
  State<DemoPhotoDetail> createState()=>_DemoPhotoDetailState();
}
class _DemoPhotoDetailState extends State<DemoPhotoDetail> {
  @override
  Widget build(BuildContext context){
    final matches=widget.store.photos.where((p)=>p.id==widget.photoId);
    if(matches.isEmpty){return Scaffold(appBar:AppBar(title:const Text('사진 상세')),body:const Center(child:Text('삭제된 체험 기록입니다.')));}
    final p=matches.first;
    return Scaffold(appBar:AppBar(title:const Text('사진 상세')),body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,48),children:[
      GestureDetector(
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (context) => Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(title: Text(p.title)),
                body: Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 6,
                    child: DemoPhotoImage(photo: p, store: widget.store, height: MediaQuery.sizeOf(context).height * .7, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          );
        },
        child: DemoPhotoImage(photo: p, store: widget.store, height: 260),
      ),
      const SizedBox(height:14),Row(children:[Expanded(child:Text(p.farmName.isEmpty?'농가 미입력':p.farmName,style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold))),_Status(photo:p)]),Text([p.crop,p.variety].where((s)=>s.isNotEmpty).join(' · ')),const SizedBox(height:12),
      ...[('기록 번호',p.number),('제목',p.title),('촬영일시',p.date.isEmpty?'미입력':'${p.date} ${p.time}'),('촬영일 출처',{'exif':'사진 정보(EXIF)','device':'촬영 시 기기 시각','manual':'직접 입력','unknown':'미확인'}[p.dateSource]??'미확인'),('주소',p.location),('위치 좌표',p.latitude==null?'미입력':'${p.latitude!.toStringAsFixed(6)}, ${p.longitude!.toStringAsFixed(6)} (${p.locationSource})'),('메모',p.note),('등록일',p.createdAt.isEmpty?'이전 체험판 기록':demoKoreanTimestamp(p.createdAt)),('등록 경로',p.isSample?'가상 샘플 삽화':'앱 · 기기에 저장')].map((r)=>ListTile(contentPadding:EdgeInsets.zero,dense:true,title:Text(r.$1,style:const TextStyle(fontSize:12,color:Color(0xff52685c))),subtitle:SelectableText(r.$2.isEmpty?'미입력':r.$2))),
      FilledButton.icon(onPressed:()async{final changed=await Navigator.of(context).push<bool>(MaterialPageRoute(builder:(_)=>DemoPhotoEditor(store:widget.store,photo:p)));if(changed==true&&mounted){widget.onChanged();setState((){});}},icon:const Icon(Icons.edit_outlined),label:const Text('정보 수정')),
      OutlinedButton.icon(onPressed:()=>demoIntegrationPreview(context,widget.store,p,widget.onChanged),icon:const Icon(Icons.preview_outlined),label:const Text('시트·Discord 연동 미리보기')),
    ])));
  }
}
Future<void> demoIntegrationPreview(BuildContext context,DemoStore store,DemoPhoto photo,VoidCallback onChanged) async {
  final text='[오프라인 체험 · 외부 전송 없음]\n사진 관리대장\n${['번호','농가명','작물','품종','촬영일','주소','메모'].join(' | ')}\n${[photo.number,photo.farmName,photo.crop,photo.variety,photo.date,photo.location,photo.note].join(' | ')}\n\nDiscord 알림 미리보기\n새 작황 사진: ${photo.farmName.isEmpty?'농가 미입력':photo.farmName}\n${photo.crop} · ${photo.variety}\n${photo.note}';
  await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(sheetContext)=>SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[const Text('업무 연동 미리보기',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:12),SelectableText(text),const SizedBox(height:16),OutlinedButton(onPressed:()=>Clipboard.setData(ClipboardData(text:text)),child:const Text('내용 복사')),FilledButton(onPressed:()async{try{await store.simulateIntegrations(photo);if(sheetContext.mounted){Navigator.pop(sheetContext);}onChanged();}catch(_){if(sheetContext.mounted){ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content:Text('체험 작업 기록을 저장하지 못했습니다.')));}}},child:const Text('기기에 체험 작업 기록 남기기')),const SizedBox(height:10),const Text('실제 Google 시트 반영이나 Discord 전송은 하지 않습니다.',style:TextStyle(fontSize:12))])))));
}
class DemoPhotoEditor extends StatefulWidget {
  const DemoPhotoEditor({super.key,required this.store,this.source,this.photo,this.metadata=const DemoPhotoMetadata()});
  final DemoStore store;
  final File? source;
  final DemoPhoto? photo;
  final DemoPhotoMetadata metadata;
  @override
  State<DemoPhotoEditor> createState()=>_DemoPhotoEditorState();
}
class _DemoPhotoEditorState extends State<DemoPhotoEditor> {
  final _form=GlobalKey<FormState>();
  late final TextEditingController _title,_farm,_crop,_variety,_address,_memo;
  late String _date,_time,_dateSource,_locationSource;
  double? _latitude,_longitude;
  bool _busy=false;
  String _error='';
  @override
  void initState(){super.initState();final p=widget.photo,m=widget.metadata;_title=TextEditingController(text:p?.title??'');_farm=TextEditingController(text:p?.farmName??'');_crop=TextEditingController(text:p?.crop??'');_variety=TextEditingController(text:p?.variety??'');_address=TextEditingController(text:p?.location??'');_memo=TextEditingController(text:p?.note??'');_date=p?.date??m.date;_time=p?.time??m.time;_dateSource=p?.dateSource??m.dateSource;_latitude=p?.latitude??m.latitude;_longitude=p?.longitude??m.longitude;_locationSource=p?.locationSource??m.locationSource;}
  @override
  void dispose(){_title.dispose();_farm.dispose();_crop.dispose();_variety.dispose();_address.dispose();_memo.dispose();super.dispose();}
  Future<void> _save() async {
    if(!_form.currentState!.validate()){return;}
    setState((){_busy=true;_error='';});
    try {
      final title=_title.text.trim().isEmpty?(_farm.text.trim().isEmpty?'현장 기록':_farm.text.trim()):_title.text.trim();
      final old=widget.photo;
      if(old==null){await widget.store.add(source:widget.source!,title:title,variety:_variety.text,location:_address.text,note:_memo.text,date:_date,farmName:_farm.text,crop:_crop.text,time:_time,dateSource:_dateSource,latitude:_latitude,longitude:_longitude,locationSource:_locationSource);}
      else {await widget.store.update(DemoPhoto(id:old.id,fileName:old.fileName,title:title,variety:_variety.text.trim(),location:_address.text.trim(),note:_memo.text.trim(),date:_date,farmName:_farm.text.trim(),crop:_crop.text.trim(),createdAt:old.createdAt,time:_time,dateSource:_dateSource,latitude:_latitude,longitude:_longitude,locationSource:_locationSource));}
      if(mounted){Navigator.pop(context,true);}
    } catch(_){if(mounted){setState((){_busy=false;_error='저장하지 못했습니다. 기기 저장 공간을 확인하고 다시 시도해 주세요.';});}}
  }
  Future<void> _locate() async {
    final allowed=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('현재 위치를 사용할까요?'),content:const Text('지금 기기의 위치를 사진 위치로 지정합니다. 예전에 찍은 사진에는 사용하지 마세요. GPS는 실내나 비행기 모드에서 오래 걸릴 수 있습니다.'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('현재 위치 지정'))]));
    if(allowed!=true||!mounted){return;}
    setState(()=>_busy=true);
    try {
      if(!await Geolocator.isLocationServiceEnabled()){throw StateError('Location disabled');}
      var permission=await Geolocator.checkPermission();
      if(permission==LocationPermission.denied){permission=await Geolocator.requestPermission();}
      if(permission==LocationPermission.denied||permission==LocationPermission.deniedForever){throw StateError('Location denied');}
      final position=await Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,timeLimit:Duration(seconds:15)));
      if(mounted){setState((){_latitude=position.latitude;_longitude=position.longitude;_locationSource='device';_error='';});}
    } catch(_){if(mounted){setState(()=>_error='위치를 가져오지 못했습니다. 기기 위치 권한을 확인하거나 주소를 직접 입력해 주세요.');}}
    finally{if(mounted){setState(()=>_busy=false);}}
  }
  Future<void> _delete() async {
    final confirm=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('이 체험 기록을 삭제할까요?'),content:const Text('앱에 저장한 사본과 기록만 지웁니다. 갤러리 원본은 지우지 않습니다.'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('삭제'))]));
    if(confirm!=true||!mounted){return;}
    setState(()=>_busy=true);
    try{await widget.store.remove(widget.photo!);if(mounted){Navigator.pop(context,true);}}catch(_){if(mounted){setState((){_busy=false;_error='삭제하지 못했습니다. 다시 시도해 주세요.';});}}
  }
  Future<void> _captureDate() async {
    final date=await showDatePicker(context:context,initialDate:DateTime.tryParse(_date)??DateTime.now(),firstDate:DateTime(1970),lastDate:DateTime(2100));
    if(date==null||!mounted){return;}
    final parts=_time.split(':');
    final time=await showTimePicker(context:context,initialTime:parts.length==2?TimeOfDay(hour:int.parse(parts[0]),minute:int.parse(parts[1])):TimeOfDay.now());
    if(!mounted){return;}
    setState((){_date=demoDay(date);if(time!=null){_time='${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}';}_dateSource='manual';});
  }
  Widget _field(TextEditingController c,String label,{int length=100,int lines=1,String? hint})=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextFormField(controller:c,enabled:!_busy,maxLength:length,maxLines:lines,decoration:InputDecoration(labelText:label,hintText:hint)));
  @override
  Widget build(BuildContext context)=>PopScope(canPop:!_busy,child:Scaffold(appBar:AppBar(title:Text(widget.photo==null?'새 작황 사진':'사진 정보 수정')),body:SafeArea(child:Form(key:_form,child:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,48),children:[
    if(widget.photo!=null) DemoPhotoImage(photo:widget.photo!,store:widget.store,height:200) else ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.file(widget.source!,cacheWidth:1600,height:200,fit:BoxFit.contain,errorBuilder:(context,error,stack)=>const SizedBox(height:100,child:Center(child:Text('사진 미리보기를 표시할 수 없습니다'))))),const SizedBox(height:16),
    _field(_farm,'농가명',hint:'예: 한결농장'),_field(_crop,'작물',hint:'예: 토마토'),_field(_variety,'품종'),
    OutlinedButton.icon(onPressed:_busy?null:_captureDate,icon:const Icon(Icons.calendar_today_outlined),label:Text(_date.isEmpty?'촬영일시 미입력 · 직접 지정':'$_date $_time')),
    Row(children:[Expanded(child:Text(_dateSource=='exif'?'사진의 촬영 정보를 불러왔습니다.':_dateSource=='device'?'촬영 당시 기기 시각입니다.':'촬영일을 모르면 비워 두세요.',style:const TextStyle(fontSize:12))),if(_date.isNotEmpty)TextButton(onPressed:_busy?null:()=>setState((){_date='';_time='';_dateSource='unknown';}),child:const Text('날짜 지우기'))]),const SizedBox(height:12),
    _field(_address,'촬영 주소',length:300,hint:'주소나 시험포 위치를 직접 입력'),
    Text(_latitude==null?'위치 정보 없음':'좌표 ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)} · ${_locationSource=='exif'?'사진 정보':'직접 지정'}',style:const TextStyle(fontSize:12)),
    Wrap(spacing:8,children:[TextButton.icon(onPressed:_busy?null:_locate,icon:const Icon(Icons.my_location,size:16),label:Text(_busy?'처리 중…':'현재 위치 지정')),if(_latitude!=null)TextButton(onPressed:_busy?null:()=>setState((){_latitude=null;_longitude=null;_locationSource='unknown';}),child:const Text('좌표 지우기'))]),
    _field(_title,'기록 제목 (선택)',length:80),_field(_memo,'메모',length:4000,lines:4),
    const Text('농가명·작물·촬영일이 부족한 사진은 “정보 보완 필요”로 모입니다. 이 체험 기록은 기기에만 저장됩니다.',style:TextStyle(fontSize:12,color:Color(0xff52685c))),const SizedBox(height:12),
    if(_error.isNotEmpty)Padding(padding:const EdgeInsets.only(bottom:12),child:Text(_error,style:TextStyle(color:Theme.of(context).colorScheme.error))),
    FilledButton.icon(key:const Key('photo-save'),onPressed:_busy?null:_save,icon:const Icon(Icons.save_outlined),label:Text(_busy?'저장 중…':widget.photo==null?'기기에 저장':'수정 저장')),
    if(widget.photo!=null)TextButton.icon(onPressed:_busy?null:_delete,icon:const Icon(Icons.delete_outline),label:const Text('체험 기록 삭제')),
  ])))));
}
