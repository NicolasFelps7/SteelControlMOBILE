import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({required this.client,this.machineId,super.key});
  final ApiClient client;
  final int? machineId;
  @override
  State<DiagnosticsScreen> createState()=>_DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  static const _files=MethodChannel('br.com.steelcontrol/reports');
  final _search=TextEditingController();
  List<Map<String,dynamic>> _machines=[],_items=[];
  String _level='',_source='';
  int? _machine;
  int _offset=0,_total=0;
  bool _busy=false;
  String? _error;
  DateTime _from=DateTime.now().subtract(const Duration(days:30)),_to=DateTime.now();
  @override
  void initState(){super.initState();_machine=widget.machineId;_load(initial:true);}
  @override
  void dispose(){_search.dispose();super.dispose();}
  Map<String,dynamic> _filters()=>{
    'de':DateTime(_from.year,_from.month,_from.day).toUtc().toIso8601String(),
    'ate':DateTime(_to.year,_to.month,_to.day,23,59,59,999).toUtc().toIso8601String(),
    if(_machine!=null)'maquinaId':_machine,
    if(_level.isNotEmpty)'nivel':_level,
    if(_source.isNotEmpty)'origem':_source,
    if(_search.text.trim().isNotEmpty)'q':_search.text.trim(),
  };
  Future<void> _load({bool initial=false}) async {
    if(_busy)return;setState((){_busy=true;_error=null;});
    try{
      if(initial){final machines=await widget.client.get('/diagnostico/maquinas') as List;if(!mounted)return;_machines=machines.whereType<Map>().map((m)=>Map<String,dynamic>.from(m)).toList();}
      final result=await widget.client.get('/diagnostico',query:{..._filters(),'limit':50,'offset':_offset}) as Map;
      if(!mounted)return;
      setState((){_items=(result['itens'] as List).whereType<Map>().map((m)=>Map<String,dynamic>.from(m)).toList();_total=(result['total'] as num).toInt();});
    }catch(e){if(mounted)setState(()=>_error=e is ApiException?e.message:'Não foi possível consultar o diagnóstico.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _date(bool from) async {
    final value=await showDatePicker(context:context,initialDate:from?_from:_to,firstDate:DateTime(2020),lastDate:DateTime.now());
    if(value!=null&&mounted)setState((){if(from)_from=value;else _to=value;});
  }
  Future<void> _export() async {
    if(_busy)return;setState(()=>_busy=true);
    try{
      final report=await widget.client.get('/diagnostico/exportar',query:_filters()) as Map;
      final saved=await _files.invokeMethod<String>('saveCsv',{'name':report['nomeArquivo'],'content':report['conteudo']});
      if(!mounted||saved==null)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(report['limitado']==true?'Salvos ${report['exportados']} de ${report['total']} eventos. Reduza o período para exportar os demais.':'Relatório salvo no local escolhido.')));
    }on MissingPluginException{
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('A exportação de arquivo está disponível no APK Android atualizado. Use o site para baixar o CSV neste dispositivo.')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e is ApiException?e.message:'Não foi possível salvar o relatório. Tente um período menor.')));}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  String _dateText(dynamic value){final date=DateTime.tryParse('$value');return date==null?'Horário indisponível':DateFormat('dd/MM/yyyy HH:mm:ss').format(date.toLocal());}
  @override
  Widget build(BuildContext context){
    return Scaffold(appBar:AppBar(title:const Text('Central de Diagnóstico'),actions:[IconButton(onPressed:_busy?null:_export,icon:const Icon(Icons.download_outlined),tooltip:'Exportar CSV')]),body:ListView(padding:const EdgeInsets.all(18),children:[
      const Text('Eventos da empresa, comunicação e orientações para resolver falhas.'),const SizedBox(height:16),
      DropdownButtonFormField<int>(value:_machines.any((m)=>m['id']==_machine)?_machine:null,isExpanded:true,decoration:const InputDecoration(labelText:'Máquina'),items:[const DropdownMenuItem<int>(value:null,child:Text('Todas as máquinas')),..._machines.map((m)=>DropdownMenuItem<int>(value:(m['id'] as num).toInt(),child:Text('${m['nome']}${m['ativo']==true?'':' (arquivada)'}',overflow:TextOverflow.ellipsis)))],onChanged:_busy?null:(v)=>setState(()=>_machine=v)),const SizedBox(height:12),
      DropdownButtonFormField<String>(value:_level,decoration:const InputDecoration(labelText:'Severidade'),items:const [DropdownMenuItem(value:'',child:Text('Todas')),DropdownMenuItem(value:'INFO',child:Text('Informação')),DropdownMenuItem(value:'WARN',child:Text('Atenção')),DropdownMenuItem(value:'ERROR',child:Text('Erro'))],onChanged:_busy?null:(v)=>setState(()=>_level=v??'')),const SizedBox(height:12),
      DropdownButtonFormField<String>(value:_source,decoration:const InputDecoration(labelText:'Origem'),items:[const DropdownMenuItem(value:'',child:Text('Todas')),...['CONEXAO','NAVEGADOR','SERVIDOR','SISTEMA','OPERACAO','COMANDO','AUDITORIA'].map((v)=>DropdownMenuItem(value:v,child:Text(v)))],onChanged:_busy?null:(v)=>setState(()=>_source=v??'')),const SizedBox(height:12),
      Row(children:[Expanded(child:OutlinedButton(onPressed:_busy?null:()=>_date(true),child:Text('De ${DateFormat('dd/MM/yyyy').format(_from)}'))),const SizedBox(width:10),Expanded(child:OutlinedButton(onPressed:_busy?null:()=>_date(false),child:Text('Até ${DateFormat('dd/MM/yyyy').format(_to)}')))]),const SizedBox(height:12),
      TextField(controller:_search,maxLength:100,decoration:const InputDecoration(labelText:'Código, máquina, usuário ou evento'),onSubmitted:(_){_offset=0;_load();}),const SizedBox(height:8),
      FilledButton.icon(onPressed:_busy?null:(){_offset=0;_load();},icon:const Icon(Icons.filter_alt_outlined),label:const Text('Aplicar filtros / Atualizar')),const SizedBox(height:16),
      if(_busy)const LinearProgressIndicator(),
      if(_error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      Text('$_total evento(s) encontrado(s)'),const SizedBox(height:10),
      if(!_busy&&_items.isEmpty&&_error==null)const Text('Nenhum evento encontrado para estes filtros.'),
      ..._items.map((e)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${_dateText(e['data'])} · ${e['nivel']} · ${e['origem']}',style:Theme.of(context).textTheme.bodySmall),const SizedBox(height:8),Text('${e['mensagem']}',style:Theme.of(context).textTheme.titleSmall),const SizedBox(height:6),Text('${e['maquina']} · ${e['usuario']}'),const SizedBox(height:8),SelectableText('${e['codigo']}'),const Divider(),Text('Como proceder: ${e['orientacao']}'),
      ])))),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[TextButton(onPressed:_busy||_offset==0?null:(){_offset=(_offset-50).clamp(0,100000).toInt();_load();},child:const Text('Anterior')),Text(_total==0?'0 eventos':'${_offset+1}–${(_offset+50).clamp(0,_total)}'),TextButton(onPressed:_busy||_offset+50>=_total?null:(){_offset+=50;_load();},child:const Text('Próxima'))]),
    ]));
  }
}
