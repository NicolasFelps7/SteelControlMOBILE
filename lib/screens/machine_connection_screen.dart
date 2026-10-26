import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/api_client.dart';

class MachineConnectionScreen extends StatefulWidget {
  const MachineConnectionScreen({required this.client, required this.machineId, required this.machineName, super.key});
  final ApiClient client;
  final int machineId;
  final String machineName;
  @override
  State<MachineConnectionScreen> createState() => _MachineConnectionScreenState();
}

class _MachineConnectionScreenState extends State<MachineConnectionScreen> {
  static const drivers = <String,String>{'AUTO':'Automático pelo cadastro','DOBOT_MAGICIAN':'Dobot Magician (USB)','SERIAL_JSON':'USB / serial JSON','MODBUS_RTU':'Modbus RTU','MODBUS_TCP':'Modbus TCP','OPC_UA':'OPC UA','MQTT':'MQTT','HTTP_REST':'HTTP / REST','TCP_IP':'TCP / IP JSON','MOCK':'Simulador'};
  final _host = TextEditingController(), _port = TextEditingController(), _baud = TextEditingController(text:'115200'), _unit = TextEditingController(text:'1'), _endpoint = TextEditingController(), _topic = TextEditingController(), _advanced = TextEditingController();
  List<Map<String,dynamic>> _computers = [];
  List<Map<String,dynamic>> _adapters = [];
  Map<String,dynamic> _capabilities = {};
  String? _hostId, _serialPort;
  String _driver = 'AUTO', _status = 'Carregando…';
  bool _busy = false, _loading = true, _commands = false, _refreshing = false;
  Timer? _timer;
  String get _path => '/conexoes/maquinas/${widget.machineId}';
  @override
  void initState() {
    super.initState();
    _load(initial:true);
    _timer = Timer.periodic(const Duration(seconds:5), (_) { if (!_busy) _load(); });
  }
  @override
  void dispose() {
    _timer?.cancel();
    for(final c in [_host,_port,_baud,_unit,_endpoint,_topic,_advanced]) { c.dispose(); }
    super.dispose();
  }
  Future<void> _load({bool initial=false}) async {
    if(_refreshing) return;
    _refreshing=true;
    try {
      final computers = await widget.client.get('/conexoes/computadores') as Map;
      final data = await widget.client.get(_path) as Map;
      if(initial) {
        final catalog = await widget.client.get('/conexoes/adaptadores') as Map;
        _adapters = (catalog['adaptadores'] as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
      }
      if(!mounted) return;
      final list = (computers['computadores'] as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
      final connection = data['conexao'];
      setState(() {
        _computers=list;
        _capabilities=Map<String,dynamic>.from(data['capacidades'] as Map? ?? {});
        if(initial && connection is Map) {
          _hostId='${connection['hostId']}'; _driver='${connection['driver']}'; _commands=connection['comandos']==true;
          final p=Map<String,dynamic>.from(connection['parametros'] as Map? ?? {});
          _serialPort=p['serialPort']?.toString();
          for(final entry in {'host':_host,'port':_port,'baud':_baud,'unitId':_unit,'endpoint':_endpoint,'topic':_topic}.entries) { if(p[entry.key]!=null) entry.value.text='${p[entry.key]}'; }
          p.removeWhere((key,_)=>['serialPort','host','port','baud','unitId','endpoint','topic'].contains(key));
          _advanced.text=p.isEmpty?'':const JsonEncoder.withIndent('  ').convert(p);
        }
        _hostId ??= list.isEmpty ? null : '${list.first['id']}';
        if(!list.any((h)=>h['id']==_hostId)) _hostId=null;
        if(list.any((h)=>h['id']==_hostId&&h['tipo']=='NAVEGADOR')) _driver='SERIAL_JSON';
        const states={'ONLINE':'Conectada','CONNECTING':'Conectando','ERROR':'Falha de comunicação','STOPPED':'Desconectada','OFFLINE':'Computador offline'};
        _status=connection is Map ? '${states[connection['estado']] ?? 'Estado indisponível'} · ${connection['computador']}' : 'Selecione o computador conectado à máquina.';
        _loading=false;
      });
    } catch(e) { if(mounted) setState(() { _status=e is ApiException?e.message:'Não foi possível consultar a conexão.'; _loading=false; }); }
    finally { _refreshing=false; }
  }
  Future<void> _save() async {
    if(_busy || _hostId==null) return;
    setState(()=>_busy=true);
    try {
      Map<String,dynamic> params={};
      if(_advanced.text.trim().isNotEmpty) {
        final decoded=jsonDecode(_advanced.text);
        if(decoded is! Map) throw const FormatException('Use um objeto JSON.');
        params=Map<String,dynamic>.from(decoded);
      }
      for(final e in {'host':_host,'port':_port,'baud':_baud,'unitId':_unit,'endpoint':_endpoint,'topic':_topic}.entries) {
        final relevant = switch(e.key) {
          'host' || 'port' => ['AUTO','MODBUS_TCP','MQTT','TCP_IP','HTTP_REST','OPC_UA'].contains(_driver),
          'baud' => ['AUTO','DOBOT_MAGICIAN','SERIAL_JSON','MODBUS_RTU'].contains(_driver),
          'unitId' => ['AUTO','MODBUS_TCP','MODBUS_RTU'].contains(_driver),
          'endpoint' => ['AUTO','OPC_UA','HTTP_REST'].contains(_driver),
          'topic' => ['AUTO','MQTT'].contains(_driver),
          _ => false,
        };
        if(!relevant) continue;
        if(e.value.text.trim().isNotEmpty) params[e.key]=['port','baud','unitId'].contains(e.key)?int.parse(e.value.text.trim()):e.value.text.trim();
      }
      if(_serialPort!=null&&['AUTO','DOBOT_MAGICIAN','SERIAL_JSON','MODBUS_RTU'].contains(_driver)) params['serialPort']=_serialPort;
      final result=await widget.client.put(_path,body:{'hostId':_hostId,'driver':_driver,'parametros':params,'comandos':_commands}) as Map;
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${result['mensagem']}')));
      await _load();
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e is ApiException?e.message:'Confira os campos de comunicação e o JSON.'),backgroundColor:SteelColors.danger));
    } finally { if(mounted) setState(()=>_busy=false); }
  }
  Future<void> _disconnect() async {
    if(_busy) return;
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Desconectar máquina?'),content:const Text('A comunicação será desativada. O histórico será preservado.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Desconectar'))]));
    if(yes!=true || !mounted) return;
    setState(()=>_busy=true);
    try { await widget.client.delete(_path); await _load(); }
    catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e is ApiException?e.message:'Não foi possível desconectar.'))); }
    finally { if(mounted) setState(()=>_busy=false); }
  }
  Widget _input(String label,TextEditingController controller,{bool number=false}) => Padding(padding:const EdgeInsets.only(bottom:14),child:TextField(controller:controller,enabled:!_busy,keyboardType:number?TextInputType.number:TextInputType.text,decoration:InputDecoration(labelText:label)));
  @override
  Widget build(BuildContext context) {
    final selected=_computers.where((h)=>h['id']==_hostId).firstOrNull;
    final browser=selected?['tipo']=='NAVEGADOR';
    final availableDrivers=browser?<String,String>{'SERIAL_JSON':drivers['SERIAL_JSON']!}:drivers;
    final monitoring=_capabilities['monitoramento'] as Map? ?? {};
    final control=_capabilities['controle'] as Map? ?? {};
    final serial=['AUTO','DOBOT_MAGICIAN','SERIAL_JSON','MODBUS_RTU'].contains(_driver);
    final network=['AUTO','MODBUS_TCP','MQTT','TCP_IP','HTTP_REST','OPC_UA'].contains(_driver);
    final ports=(selected?['portas'] as List? ?? []).whereType<Map>().toList();
    final validPort=ports.any((p)=>p['porta']==_serialPort)?_serialPort:null;
    return Scaffold(appBar:AppBar(title:const Text('Conexão da máquina'),actions:[IconButton(onPressed:_busy?null:()=>_load(),icon:const Icon(Icons.refresh),tooltip:'Atualizar')]),body:_loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(20),children:[
      Text(widget.machineName,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[const Icon(Icons.settings_input_component_outlined,color:SteelColors.industrialAccent),const SizedBox(width:12),Expanded(child:Text(_status))]))),const SizedBox(height:16),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Cadastro: qualquer categoria de máquina'),const SizedBox(height:8),Text('Monitoramento: ${_capabilities['situacao']=='SIMULACAO'?'simulação':monitoring['confirmado']==true?'comunicação confirmada':'aguardando comunicação real'}'),const SizedBox(height:8),Text('Controle: ${control['habilitado']==true?'habilitado conforme permissões':'bloqueado'}')]))),const SizedBox(height:16),
      if(_computers.isEmpty) const Padding(padding:EdgeInsets.only(bottom:20),child:Text('Abra o site SteelControl no Chrome ou Edge do computador ligado à máquina. Em Máquinas → Conexões, autorize a porta USB e mantenha a aba aberta. O mobile usará essa conexão, sem instalar programa no computador.')),
      DropdownButtonFormField<String>(value:_hostId,isExpanded:true,decoration:const InputDecoration(labelText:'Computador / navegador'),items:_computers.map((h)=>DropdownMenuItem<String>(value:'${h['id']}',child:Text('${h['nome']}${h['online']==true?'':' — offline'}',overflow:TextOverflow.ellipsis))).toList(),onChanged:_busy?null:(v)=>setState(() { _hostId=v; _serialPort=null; if(_computers.any((h)=>h['id']==v&&h['tipo']=='NAVEGADOR')) _driver='SERIAL_JSON'; })),const SizedBox(height:14),
      DropdownButtonFormField<String>(value:_driver,isExpanded:true,decoration:const InputDecoration(labelText:'Protocolo'),items:availableDrivers.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:_busy?null:(v)=>setState(()=>_driver=v??'AUTO')),const SizedBox(height:14),
      if(serial) ...[
      DropdownButtonFormField<String>(value:validPort,isExpanded:true,decoration:const InputDecoration(labelText:'Porta USB / serial'),items:ports.map((p)=>DropdownMenuItem<String>(value:'${p['porta']}',child:Text('${p['porta']} — ${p['nome']}',overflow:TextOverflow.ellipsis))).toList(),onChanged:_busy?null:(v)=>setState(()=>_serialPort=v)),const SizedBox(height:14),
      _input('Baud rate',_baud,number:true)],
      if(network) ...[_input('IP / host',_host),_input('Porta de rede',_port,number:true)],
      if(['AUTO','MODBUS_TCP','MODBUS_RTU'].contains(_driver)) _input('Unit ID (Modbus)',_unit,number:true),
      if(['AUTO','OPC_UA','HTTP_REST'].contains(_driver)) _input('Endpoint',_endpoint),
      if(['AUTO','MQTT'].contains(_driver)) _input('Tópico MQTT',_topic),
      ExpansionTile(title:const Text('Protocolos e requisitos'),children:_adapters.map((a)=>ListTile(title:Text('${a['nome']}'),subtitle:Text('${(a['ambientes'] as List? ?? []).contains('NAVEGADOR')?'Disponível na aba do computador. ':'Exige integração ou ponte compatível. '}${a['observacao']}'))).toList()),
      ExpansionTile(title:const Text('Configuração avançada'),children:[TextField(controller:_advanced,maxLines:4,decoration:const InputDecoration(labelText:'Parâmetros do fabricante (JSON)'))]),
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Permitir comandos autorizados'),subtitle:const Text('Também exige cargo permitido e controle remoto habilitado na máquina.'),value:_commands,onChanged:_busy?null:(v)=>setState(()=>_commands=v)),
      Text(browser?'Mantenha a aba do site aberta no computador. Recarregar ou sair encerra o USB; autorize novamente e salve a conexão.':'O computador selecionado deve permanecer ligado e conectado.'),const Text('Desconectar não substitui a parada de emergência física.'),const SizedBox(height:20),
      FilledButton.icon(onPressed:_busy||_hostId==null?null:_save,icon:_busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.cable),label:const Text('Salvar e conectar')),const SizedBox(height:10),OutlinedButton(onPressed:_busy?null:_disconnect,child:const Text('Desconectar')),
    ]));
  }
}
