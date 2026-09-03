import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/app_strings.dart';
import '../services/api_client.dart';
import '../state/app_controller.dart';
import '../widgets/steel_brand.dart';
import 'face_auth_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    try {
      await widget.controller.login(_email.text, _password.text);
    } on ApiException catch (exception) {
      if (!mounted) return;
      _message(exception.message, error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? SteelColors.danger : SteelColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tablet = constraints.maxWidth >= 760;
            final form = _LoginForm(
              showBrand: !tablet,
              formKey: _formKey,
              email: _email,
              password: _password,
              obscure: _obscure,
              busy: widget.controller.busy,
              strings: strings,
              onTogglePassword: () => setState(() => _obscure = !_obscure),
              onLogin: _login,
              onFace: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FaceAuthScreen(controller: widget.controller)),
              ),
              onRegister: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RegisterScreen(controller: widget.controller)),
              ),
            );

            return Stack(
              children: [
                Row(
                  children: [
                    if (tablet) const Expanded(flex: 5, child: _IndustrialPanel()),
                    Expanded(
                      flex: tablet ? 6 : 1,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: tablet ? 64 : 24,
                          vertical: tablet ? 46 : 28,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 510),
                            child: form,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _PreferencesButton(controller: widget.controller),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PreferencesButton extends StatelessWidget {
  const _PreferencesButton({required this.controller});
  final AppController controller;

  Future<void> _open(BuildContext context) => showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final strings = AppStrings.of(dialogContext);
          return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 46, height: 46, decoration: BoxDecoration(color: SteelColors.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.tune_rounded, color: SteelColors.primary)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.get('preferences'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(strings.get('adjustExperience'), style: const TextStyle(color: SteelColors.muted))])),
                  IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded)),
                ]),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Theme.of(dialogContext).colorScheme.surfaceContainerHighest.withValues(alpha: .55), borderRadius: BorderRadius.circular(17)),
                  child: Row(children: [
                    Icon(controller.darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: SteelColors.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.get('appearance'), style: const TextStyle(fontWeight: FontWeight.w800)), Text(strings.get('themeApplied'), style: const TextStyle(color: SteelColors.muted, fontSize: 12))])),
                    SegmentedButton<bool>(segments: [ButtonSegment(value: false, icon: const Icon(Icons.light_mode_outlined), tooltip: strings.get('lightTheme')), ButtonSegment(value: true, icon: const Icon(Icons.dark_mode_outlined), tooltip: strings.get('darkTheme'))], selected: {controller.darkMode}, showSelectedIcon: false, onSelectionChanged: (value) => controller.setDarkMode(value.first)),
                  ]),
                ),
                const SizedBox(height: 22),
                Text(strings.get('interfaceLanguage').toUpperCase(), style: const TextStyle(color: SteelColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 11),
                Wrap(spacing: 8, runSpacing: 8, children: ['Português', 'English', 'Español', 'Français', 'Deutsch', 'Italiano'].asMap().entries.map((entry) {
                  final selected = controller.language == AppLanguage.values[entry.key];
                  return ChoiceChip(avatar: Icon(selected ? Icons.check_circle_rounded : Icons.language_rounded, size: 17, color: selected ? SteelColors.primary : SteelColors.muted), label: Text(entry.value), selected: selected, onSelected: (_) => controller.setLanguage(AppLanguage.values[entry.key]));
                }).toList()),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(dialogContext), child: Text(strings.get('finish')))),
              ]),
            ),
          ),
        );
        },
      );

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(tooltip: AppStrings.of(context).get('themeAndLanguage'), onPressed: () => _open(context), icon: const Icon(Icons.settings_outlined));
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.showBrand,
    required this.formKey,
    required this.email,
    required this.password,
    required this.obscure,
    required this.busy,
    required this.strings,
    required this.onTogglePassword,
    required this.onLogin,
    required this.onFace,
    required this.onRegister,
  });

  final bool showBrand;
  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final bool busy;
  final AppStrings strings;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final VoidCallback onFace;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showBrand) ...[
            const SteelBrand(),
            const SizedBox(height: 42),
          ] else
            const SizedBox(height: 12),
          Text(strings.get('platform'), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: SteelColors.primary, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Text(strings.get('accessCompany'), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.2)),
          const SizedBox(height: 12),
          Text(strings.get('loginCaption'), style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SteelColors.muted, height: 1.5)),
          const SizedBox(height: 30),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: strings.get('email'), prefixIcon: const Icon(Icons.mail_outline_rounded)),
            validator: (value) => value?.contains('@') == true ? null : strings.get('validEmail'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: password,
            obscureText: obscure,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: strings.get('password'),
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(onPressed: onTogglePassword, icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
            ),
            validator: (value) => (value?.length ?? 0) >= 8 ? null : strings.get('minimumPassword'),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: busy ? null : onLogin,
            icon: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(strings.get('enterCompany')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : onFace,
            icon: const Icon(Icons.face_retouching_natural_rounded),
            label: Text(strings.get('faceSignIn')),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(strings.get('newCompany'), style: Theme.of(context).textTheme.labelSmall)),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 18),
          TextButton.icon(onPressed: onRegister, icon: const Icon(Icons.add_business_outlined), label: Text(strings.get('registerCompany'))),
        ],
      ),
    );
  }
}

class _IndustrialPanel extends StatelessWidget {
  const _IndustrialPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.all(44),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [SteelColors.ink, Color(0xFF173B82)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SteelBrand(light: true),
          const Spacer(),
          const Icon(Icons.monitor_heart_outlined, color: Color(0xFF7FB3FF), size: 58),
          const SizedBox(height: 26),
          Text(AppStrings.of(context).get('heroTitle'), style: const TextStyle(color: Colors.white, fontSize: 37, height: 1.08, fontWeight: FontWeight.w800, letterSpacing: -1.2)),
          const SizedBox(height: 18),
          Text(AppStrings.of(context).get('heroCaption'), style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.55)),
          const Spacer(),
          Row(children: [const Icon(Icons.shield_outlined, color: Colors.white70), const SizedBox(width: 10), Text(AppStrings.of(context).get('protectedAccess'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))]),
        ],
      ),
    );
  }
}
