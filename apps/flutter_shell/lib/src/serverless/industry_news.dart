import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'client.dart';

class IndustryNewsPage extends StatefulWidget {
  const IndustryNewsPage({super.key,required this.client,required this.onAuthError});
  final AppsScriptPlatformClient client;
  final Future<void> Function(Object) onAuthError;
  @override
  State<IndustryNewsPage> createState()=>_IndustryNewsPageState();
}

class _IndustryNewsPageState extends State<IndustryNewsPage> {
  static const _tracks=['전체','작물·품종','업계·경쟁사','병해충·작황','수입·검역·통관','정책·R&D·수출'];
  final _searchController=TextEditingController();
  List<Map<String,dynamic>> _articles=[];
  List<Map<String,dynamic>> _sources=[];
  String _selectedTrack='전체';
  String _query='';
  String _error='';
  bool _busy=false;
  bool _cached=false;
  String _fetchedAt='';
  final _expandedRelated=<String>{};

  @override
  void initState(){
    super.initState();
    _load();
  }

  @override
  void dispose(){
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleError(Object error) async {
    if(error is PlatformAuthFailure&&const {'AUTH_REQUIRED','SESSION_EXPIRED','ACCESS_DENIED','IDENTITY_CHANGED'}.contains(error.code)){
      await widget.onAuthError(error);
    }
    if(mounted){
      setState(()=>_error=error is PlatformAuthFailure?error.message:'업계 뉴스를 불러오지 못했습니다. 다시 시도해 주세요.');
    }
  }

  Future<void> _load({bool refresh=false}) async {
    if(_busy){return;}
    setState((){_busy=true;_error='';});
    try{
      final data=await widget.client.call('news.list',params:refresh?const {'refresh':true}:const {});
      if(!mounted){return;}
      setState((){
        _articles=List<Map<String,dynamic>>.from((data['articles'] as List? ?? []).map((e)=>Map<String,dynamic>.from(e as Map)));
        _sources=List<Map<String,dynamic>>.from((data['sources'] as List? ?? []).map((e)=>Map<String,dynamic>.from(e as Map)));
        _cached=data['cached']==true;
        _fetchedAt='${data['fetchedAt']??''}';
      });
    }catch(error){
      await _handleError(error);
    }finally{
      if(mounted){setState(()=>_busy=false);}
    }
  }

  Future<void> _markIrrelevant(Map<String,dynamic> article) async {
    final id='${article['id']??''}';
    if(id.isEmpty){return;}
    try{
      await widget.client.call('news.feedback',params:{'id':id,'title':'${article['title']??''}','reason':'관련 없음'});
      if(!mounted){return;}
      setState(()=>_articles.removeWhere((a)=>'${a['id']}'==id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('관련 없는 기사로 기록해 목록에서 제외했습니다.')));
    }catch(error){
      await _handleError(error);
    }
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri=Uri.tryParse(rawUrl.trim());
    if(uri==null||!(uri.scheme=='http'||uri.scheme=='https')){
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('열 수 없는 기사 링크입니다.')));}
      return;
    }
    final ok=await launchUrl(uri,mode:LaunchMode.externalApplication);
    if(!ok&&mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('브라우저에서 기사 링크를 열지 못했습니다.')));}
  }

  String _formatKst(String iso){
    final dt=DateTime.tryParse(iso)?.toUtc().add(const Duration(hours:9));
    if(dt==null){return '';}
    final mm=dt.month.toString().padLeft(2,'0');
    final dd=dt.day.toString().padLeft(2,'0');
    final hh=dt.hour.toString().padLeft(2,'0');
    final min=dt.minute.toString().padLeft(2,'0');
    return '$mm.$dd $hh:$min';
  }

  @override
  Widget build(BuildContext context){
    final q=_query.trim().toLowerCase();
    final visible=_articles.where((a){
      if(_selectedTrack!='전체'&&'${a['track']}'!=_selectedTrack){return false;}
      if(q.isEmpty){return true;}
      final hay='${a['title']} ${a['facts']} ${a['source']} ${(a['crops'] as List? ?? []).join(' ')}'.toLowerCase();
      return hay.contains(q);
    }).toList();
    final okSources=_sources.where((s)=>s['enabled']==true&&'${s['lastError']??''}'.isEmpty).length;
    final totalSources=_sources.where((s)=>s['enabled']==true).length;

    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Padding(
        padding:const EdgeInsets.fromLTRB(12,10,12,4),
        child:Row(children:[
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('종자·농업 업계 뉴스',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
            if(totalSources>0)Text('활성 매체 $okSources/$totalSources곳 · ${_cached?'캐시 표시':'최신 조회'}${_fetchedAt.isNotEmpty?' (${_formatKst(_fetchedAt)})':''}',style:const TextStyle(fontSize:12,color:Color(0xff52685c))),
          ])),
          IconButton(key:const Key('news-refresh'),tooltip:'뉴스 새로고침',onPressed:_busy?null:()=>_load(refresh:true),icon:const Icon(Icons.refresh)),
        ]),
      ),
      Padding(
        padding:const EdgeInsets.symmetric(horizontal:12),
        child:TextField(
          key:const Key('news-search'),
          controller:_searchController,
          onChanged:(v)=>setState(()=>_query=v),
          decoration:InputDecoration(
            labelText:'제목·작물·매체 검색',
            hintText:'예: 토마토, 바이러스, 품종',
            suffixIcon:_query.isEmpty
              ?const Icon(Icons.search)
              :IconButton(icon:const Icon(Icons.clear),onPressed:(){_searchController.clear();setState(()=>_query='');}),
          ),
        ),
      ),
      const SizedBox(height:8),
      SingleChildScrollView(
        scrollDirection:Axis.horizontal,
        padding:const EdgeInsets.symmetric(horizontal:12),
        child:Row(children:[
          for(final t in _tracks)Padding(
            padding:const EdgeInsets.only(right:6),
            child:ChoiceChip(
              key:ValueKey('news-track-$t'),
              label:Text(t),
              selected:_selectedTrack==t,
              onSelected:(_)=>setState(()=>_selectedTrack=t),
            ),
          ),
        ]),
      ),
      if(_busy)const Padding(padding:EdgeInsets.only(top:6),child:LinearProgressIndicator()),
      if(_error.isNotEmpty)Padding(padding:const EdgeInsets.all(12),child:Text(_error,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      Expanded(
        child:visible.isEmpty&&!_busy
          ?Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(_articles.isEmpty?'수집된 업계 뉴스가 아직 없습니다.\n관리대장 시트에서 수집을 실행하면 여기에 표시됩니다.':'선택한 조건에 맞는 기사가 없습니다.',textAlign:TextAlign.center)))
          :ListView.builder(
            padding:const EdgeInsets.fromLTRB(12,6,12,16),
            itemCount:visible.length,
            itemBuilder:(context,index){
              final a=visible[index];
              final id='${a['id']??''}';
              final crops=List<String>.from((a['crops'] as List? ?? []).map((e)=>'$e'));
              final facts='${a['facts']??''}'.trim();
              final aiNote='${a['aiNote']??''}'.trim();
              final related=List<Map<String,dynamic>>.from((a['relatedUrls'] as List? ?? []).map((e)=>Map<String,dynamic>.from(e as Map)));
              final relatedExpanded=_expandedRelated.contains(id);
              final timeLabel=_formatKst('${a['publishedAt']??a['scrapedAt']??''}');
              return Card(
                key:ValueKey('news-card-$id'),
                margin:const EdgeInsets.symmetric(vertical:6),
                child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                  Wrap(spacing:6,runSpacing:4,crossAxisAlignment:WrapCrossAlignment.center,children:[
                    Container(
                      padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
                      decoration:BoxDecoration(color:const Color(0xffe7efe9),borderRadius:BorderRadius.circular(8)),
                      child:Text('${a['track']??'기타'}',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:Color(0xff1e6247))),
                    ),
                    for(final c in crops)Container(
                      padding:const EdgeInsets.symmetric(horizontal:7,vertical:2),
                      decoration:BoxDecoration(color:const Color(0xffeef4fa),borderRadius:BorderRadius.circular(8)),
                      child:Text(c,style:const TextStyle(fontSize:11,color:Color(0xff1e3a4c))),
                    ),
                  ]),
                  const SizedBox(height:8),
                  Text('${a['title']??''}',style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold)),
                  const SizedBox(height:4),
                  Text('${a['source']??''}${timeLabel.isNotEmpty?' · $timeLabel KST':''}',style:const TextStyle(fontSize:12,color:Color(0xff52685c))),
                  if(facts.isNotEmpty)...[
                    const SizedBox(height:8),
                    Text(facts,style:const TextStyle(fontSize:13,height:1.45)),
                  ],
                  if(aiNote.isNotEmpty)Container(
                    margin:const EdgeInsets.only(top:8),
                    padding:const EdgeInsets.all(8),
                    decoration:BoxDecoration(color:const Color(0xfff5f8f5),borderRadius:BorderRadius.circular(8)),
                    child:Text('[AI 추정] $aiNote',style:const TextStyle(fontSize:12,color:Color(0xff385245))),
                  ),
                  if(related.isNotEmpty)...[
                    const SizedBox(height:6),
                    InkWell(
                      onTap:()=>setState((){
                        if(relatedExpanded){_expandedRelated.remove(id);}
                        else{_expandedRelated.add(id);}
                      }),
                      child:Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[
                        Text('유사보도 ${related.length}건',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:Color(0xff1e6247))),
                        Icon(relatedExpanded?Icons.expand_less:Icons.expand_more,size:16,color:const Color(0xff1e6247)),
                      ])),
                    ),
                    if(relatedExpanded)for(final r in related)Padding(
                      padding:const EdgeInsets.only(left:8,top:2,bottom:2),
                      child:InkWell(
                        onTap:()=>_openUrl('${r['url']??''}'),
                        child:Text('• [${r['source']??''}] ${r['title']??''}',style:const TextStyle(fontSize:12,decoration:TextDecoration.underline)),
                      ),
                    ),
                  ],
                  const Divider(height:18),
                  Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                    TextButton.icon(
                      key:ValueKey('news-irrelevant-$id'),
                      onPressed:()=>_markIrrelevant(a),
                      icon:const Icon(Icons.visibility_off_outlined,size:16),
                      label:const Text('관련 없음'),
                    ),
                    FilledButton.tonalIcon(
                      key:ValueKey('news-open-$id'),
                      onPressed:()=>_openUrl('${a['url']??''}'),
                      icon:const Icon(Icons.open_in_new,size:16),
                      label:const Text('원문 보기'),
                    ),
                  ]),
                ])),
              );
            },
          ),
      ),
    ]);
  }
}
