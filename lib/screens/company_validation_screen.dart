import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../state/app_controller.dart';

class CompanyValidationScreen extends StatefulWidget {
  const CompanyValidationScreen({required this.controller, required this.validationToken, super.key});
  final AppController controller;
  final String validationToken;
  @override State<CompanyValidationScreen> createState() => _CompanyValidationScreenState();
}
class _CompanyValidationScreenState extends State<CompanyValidationScreen> {
  Map<String, dynamic>? _challenge;
  bool _busy = false;
  bool _approved = false;
  String _message = '';
  ApiClient get _client => ApiClient(token: widget.validationToken, language: widget.controller.language);

  Future<void> _generate() async {
    setState(() { _busy = true; _message = ''; });
    try {
      final raw = await _client.post('/auth/company-authorization/challenge');
      final challenge = Map<String, dynamic>.from(raw as Map);
      if (!mounted) return;
      setState(() => _challenge = challenge);
      final bytes = Uint8List.fromList(utf8.encode('${challenge['documento']}'));
      final saved = await FilePicker.platform.saveFile(dialogTitle: 'Salvar autorização para assinatura e-CNPJ', fileName: '${challenge['arquivo']}', bytes: bytes);
      if (saved != null && !Platform.isAndroid && !Platform.isIOS) await File(saved).writeAsBytes(bytes);
      if (mounted) setState(() => _message = saved == null ? 'Salvamento cancelado. Gere novamente para baixar a autorização.' : 'Arquivo salvo. Confira a conta e assine com o e-CNPJ da empresa.');
    } on ApiException catch (e) { if (mounted) setState(() => _message = e.message); }
    catch (_) { if (mounted) setState(() => _message = 'Não foi possível salvar o arquivo. Tente novamente.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _verify() async {
    if (_challenge == null) return;
    final selected = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['p7s'], allowMultiple: false, withData: false);
    if (!mounted || selected == null) return;
    final file = selected.files.single;
    if (file.path == null || file.size == 0 || file.size > 1024 * 1024 || !file.name.toLowerCase().endsWith('.p7s')) {
      setState(() => _message = 'Escolha somente a assinatura .p7s de até 1 MB. Não envie PFX, P12 ou chave privada.'); return;
    }
    setState(() { _busy = true; _message = 'Validando assinatura, certificado, CNPJ e revogação...'; });
    try {
      final result = await _client.multipart('/auth/company-authorization/verify', files: {'assinatura': File(file.path!)}, fields: {'autorizacaoId': '${_challenge!['autorizacaoId']}'}, binaryFiles: true);
      if (mounted) setState(() { _approved = true; _message = '${(result as Map)['mensagem']}'; });
    } on ApiException catch (e) { if (mounted) setState(() => _message = e.message); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Autorização e-CNPJ')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Confirme o responsável pela empresa', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      const Text('Baixe a autorização, confira o CNPJ, a conta e o endereço do SteelControl. Assine o arquivo original com o e-CNPJ da empresa em CMS/CAdES destacado (.p7s, DER, SHA-256 ou superior). Envie somente a assinatura. Nunca envie PFX, P12, chave privada ou senha do certificado.'),
      const SizedBox(height: 16),
      if (!_approved) FilledButton(onPressed: _busy ? null : _generate, child: const Text('Gerar e salvar autorização')),
      if (_challenge != null && !_approved) ...[
        const SizedBox(height: 16),
        SelectableText('${_challenge!['documento']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _verify, child: const Text('Selecionar .p7s e validar')),
      ],
      const SizedBox(height: 16),
      if (_busy) const LinearProgressIndicator(),
      Text(_message),
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context, _approved), child: const Text('Voltar ao login')),
    ])))),
  );
}
