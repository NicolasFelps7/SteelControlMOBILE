import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const machine3dKinds = <(String, String)>[
  ('dobot', 'Dobot Magician'),
  ('robot', 'Robô industrial'),
  ('conveyor', 'Esteira industrial'),
  ('injection', 'Injetora'),
  ('cnc', 'Fresadora CNC'),
  ('lathe', 'Torno CNC'),
  ('press', 'Prensa hidráulica'),
  ('printer', 'Impressora 3D'),
  ('packer', 'Embaladora'),
  ('filler', 'Envasadora'),
  ('welder', 'Célula de solda'),
  ('compressor', 'Compressor'),
  ('furnace', 'Forno industrial'),
  ('plc', 'Painel CLP'),
  ('generic', 'Outro equipamento'),
];

/// Cena local: recebe apenas identificação, estado e juntas medidas; nunca tokens.
class MachineModel3D extends StatefulWidget {
  const MachineModel3D({
    required this.machines,
    this.selectedId,
    this.onSelect,
    this.factoryScene = false,
    super.key,
  });
  final List<Map<String, dynamic>> machines;
  final int? selectedId;
  final ValueChanged<int>? onSelect;
  final bool factoryScene;
  @override
  State<MachineModel3D> createState() => _MachineModel3DState();
}

class _MachineModel3DState extends State<MachineModel3D> {
  WebViewController? _view;
  Timer? _startupTimer;
  bool _ready = false, _sending = false;
  String? _error, _lastSent;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      _error = 'A visualização 3D está disponível no Android/iOS e no navegador do desktop.';
      return;
    }
    try {
      final view = WebViewController();
      _view = view;
      await view.setJavaScriptMode(JavaScriptMode.unrestricted);
      await view.setBackgroundColor(const Color(0xff131e26));
      await view.enableZoom(false);
      await view.addJavaScriptChannel(
        'SteelBridge',
        onMessageReceived: (message) {
          if (!mounted || message.message.length > 1024) return;
          try {
            final data = jsonDecode(message.message);
            if (data is! Map) return;
            if (data['type'] == 'ready') {
              _startupTimer?.cancel();
              setState(() {
                _ready = true;
              });
              _push();
            } else if (data['type'] == 'select' &&
                data['id'] is int &&
                widget.machines.any((m) => m['id'] == data['id']))
              widget.onSelect?.call(data['id'] as int);
            else if (data['type'] == 'error')
              setState(
                () => _error = '3D indisponível. Atualize o Android System WebView e confira a aceleração gráfica.',
              );
          } catch (_) {
            /* Mensagens fora do contrato são descartadas. */
          }
        },
      );
      await view.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            return request.url == 'about:blank' ||
                    (uri?.scheme == 'file' &&
                        uri!.path.endsWith('/assets/industrial3d/index.html'))
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true)
              setState(
                () => _error =
                    'Não foi possível carregar o visualizador 3D local.',
              );
          },
        ),
      );
      if (!mounted) return;
      setState(() {});
      _startupTimer = Timer(const Duration(seconds: 30), () {
        if (mounted && !_ready && _error == null) {
          setState(
            () => _error = 'O visualizador 3D não respondeu. Reabra a máquina para tentar novamente.',
          );
        }
      });
      await view.loadFlutterAsset('assets/industrial3d/index.html');
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Não foi possível iniciar o 3D neste dispositivo.',
        );
    }
  }

  Map<String, dynamic> _state() => {
    'selectedId': widget.selectedId,
    'factoryScene': widget.factoryScene,
    'machines': widget.machines
        .take(100)
        .map(
          (m) => {
            'id': m['id'],
            'nome': '${m['nome'] ?? ''}',
            'tipo': '${m['tipo'] ?? ''}',
            'modelo': '${m['modelo'] ?? ''}',
            'controlador': '${m['controlador'] ?? ''}',
            'online': m['online'] == true,
            'simulacao': m['simulacao'] == true,
            if (m['joints'] is Map)
              'joints': {
                for (final key in ['j1', 'j2', 'j3', 'j4'])
                  if ((m['joints'] as Map)[key] is num &&
                      ((m['joints'] as Map)[key] as num).isFinite &&
                      ((m['joints'] as Map)[key] as num).abs() <= 360)
                    key: (m['joints'] as Map)[key],
              },
          },
        )
        .toList(),
  };
  Future<void> _push() async {
    if (!mounted || !_ready || _view == null || _sending) return;
    final json = jsonEncode(_state());
    if (json == _lastSent) return;
    _sending = true;
    try {
      await _view!.runJavaScript(
        'window.Steel3D && window.Steel3D.setState($json);',
      );
      _lastSent = json;
    } catch (_) {
      if (mounted)
        setState(() => _error = 'A cena 3D foi interrompida. Reabra a tela.');
    } finally {
      _sending = false;
    }
    if (mounted &&
        _ready &&
        _error == null &&
        jsonEncode(_state()) != _lastSent)
      unawaited(_push());
  }

  @override
  void didUpdateWidget(covariant MachineModel3D old) {
    super.didUpdateWidget(old);
    _push();
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    _ready = false;
    unawaited(
      _view
              ?.runJavaScript('window.Steel3D?.dispose();')
              .catchError((Object _) {}) ??
          Future<void>.value(),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xff131e26),
    child: Stack(
      children: [
        if (_view != null)
          Positioned.fill(
            child: WebViewWidget(
              controller: _view!,
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
            ),
          ),
        if (!_ready && _error == null)
          const Center(
            child: CircularProgressIndicator(color: Color(0xffed941f)),
          ),
        if (_error != null)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xff131e26),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

String machine3dKind(Map<String, dynamic> machine) {
  String clean(dynamic v) {
    var s = '${v ?? ''}'.toLowerCase();
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s;
  }

  String? resolve(String s) {
    for (final rule in <(String, String)>[
      ('dobot|magician', 'dobot'),
      ('impressora.*3d|3d.*print', 'printer'),
      ('injet|inject', 'injection'),
      ('esteira|conveyor', 'conveyor'),
      ('torno|lathe', 'lathe'),
      ('fresa|cnc|machining', 'cnc'),
      (r'prensa|hydraulic.?press|\bpress\b', 'press'),
      ('embala|packag|packer', 'packer'),
      ('envasa|fill', 'filler'),
      ('solda|weld', 'welder'),
      ('compress', 'compressor'),
      ('forno|furnace|oven', 'furnace'),
      ('robo|robot|braco', 'robot'),
      ('clp|plc|painel', 'plc'),
    ]) {
      if (RegExp(rule.$1).hasMatch(s)) return rule.$2;
    }
    return null;
  }

  final explicit = resolve(clean(machine['tipo']));
  if (explicit != null)
    return explicit == 'robot' &&
            clean(machine['controlador']).contains('dobot')
        ? 'dobot'
        : explicit;
  return resolve(
        clean('${machine['modelo'] ?? ''} ${machine['nome'] ?? ''}'),
      ) ??
      resolve(clean(machine['controlador'])) ??
      'generic';
}
