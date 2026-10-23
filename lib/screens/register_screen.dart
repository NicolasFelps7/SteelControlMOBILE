import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/app_strings.dart';
import '../core/cnpj_formatter.dart';
import '../services/api_client.dart';
import '../state/app_controller.dart';
import 'face_auth_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _cnpj = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  String? _verificationId;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [_company, _cnpj, _name, _email, _password, _code]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final response = await widget.controller.auth.requestRegistrationCode(
        companyName: _company.text,
        cnpj: _cnpj.text,
        adminName: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      setState(() => _verificationId = '${response['verificacaoId'] ?? ''}');
      _message('${response['mensagem'] ?? AppStrings.of(context).get('codeSent')}');
    } on ApiException catch (exception) {
      _message(exception.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCode() async {
    if (_code.text.replaceAll(RegExp(r'\D'), '').length != 6) {
      _message(AppStrings.of(context).get('enterSixDigitCode'), error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final response = await widget.controller.auth.confirmRegistrationCode(
        _verificationId!,
        _code.text,
      );
      if (!mounted) return;

      final completedSession = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => FaceAuthScreen(
            controller: widget.controller,
            registrationId: '${response['verificacaoId'] ?? _verificationId ?? ''}',
          ),
        ),
      );

      if (completedSession != null && mounted) {
        await widget.controller.acceptRegisteredSession(completedSession);
        if (!mounted) return;
        Navigator.pop(context);
      } else if (mounted) {
        _message(
          AppStrings.of(context).get('registrationFaceRequired'),
          error: true,
        );
      }
    } on ApiException catch (exception) {
      _message(exception.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? SteelColors.danger : SteelColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waitingCode = _verificationId?.isNotEmpty == true;
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.get('registerCompanyTitle'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(strings.get('startSteelControl'), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: SteelColors.primary, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(strings.get('createCompanyWorkspace'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Text(strings.get('registrationIntro')),
                        const SizedBox(height: 28),
                        _SectionLabel(number: '01', title: strings.get('companyData')),
                        const SizedBox(height: 14),
                        TextFormField(controller: _company, enabled: !waitingCode, decoration: InputDecoration(labelText: strings.get('companyName'), prefixIcon: const Icon(Icons.factory_outlined)), validator: _required),
                        const SizedBox(height: 14),
                        TextFormField(controller: _cnpj, enabled: !waitingCode, keyboardType: TextInputType.number, inputFormatters: [CnpjInputFormatter()], maxLength: 18, decoration: const InputDecoration(labelText: 'CNPJ', hintText: '00.000.000/0000-00', counterText: '', prefixIcon: Icon(Icons.business_outlined)), validator: (value) => (value ?? '').replaceAll(RegExp(r'\D'), '').length == 14 ? null : strings.get('requiredField')),
                        const SizedBox(height: 24),
                        _SectionLabel(number: '02', title: strings.get('administrator')),
                        const SizedBox(height: 14),
                        TextFormField(controller: _name, enabled: !waitingCode, decoration: InputDecoration(labelText: strings.get('fullName'), prefixIcon: const Icon(Icons.person_outline_rounded)), validator: _required),
                        const SizedBox(height: 14),
                        TextFormField(controller: _email, enabled: !waitingCode, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: strings.get('corporateEmail'), prefixIcon: const Icon(Icons.mail_outline_rounded)), validator: (value) => value?.contains('@') == true ? null : strings.get('validEmail')),
                        const SizedBox(height: 14),
                        TextFormField(controller: _password, enabled: !waitingCode, obscureText: true, decoration: InputDecoration(labelText: strings.get('password'), prefixIcon: const Icon(Icons.lock_outline_rounded)), validator: (value) => (value?.length ?? 0) >= 8 ? null : strings.get('minimumPassword')),
                        if (waitingCode) ...[
                          const SizedBox(height: 24),
                          _SectionLabel(number: '03', title: strings.get('emailConfirmation')),
                          const SizedBox(height: 14),
                          TextFormField(controller: _code, maxLength: 6, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8), decoration: InputDecoration(labelText: strings.get('sixDigitCode'), counterText: '')),
                        ],
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _busy ? null : (waitingCode ? _confirmCode : _requestCode),
                          icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(waitingCode ? Icons.verified_outlined : Icons.arrow_forward_rounded),
                          label: Text(waitingCode ? strings.get('confirmAndRegisterFace') : strings.get('verifyEmailContinue')),
                        ),
                        if (waitingCode)
                          TextButton(
                            onPressed: _busy ? null : () => setState(() => _verificationId = null),
                            child: Text(strings.get('changeData')),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) => value?.trim().isNotEmpty == true ? null : AppStrings.of(context).get('requiredField');
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: SteelColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)),
            child: Text(number, style: const TextStyle(color: SteelColors.primary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      );
}
