import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../core/app_strings.dart';
import '../core/app_theme.dart';
import '../core/cnpj_formatter.dart';
import '../models/session.dart';
import '../services/api_client.dart';
import '../state/app_controller.dart';
import '../widgets/section_card.dart';
import '../widgets/company_logo.dart';
import 'face_auth_screen.dart';

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({required this.controller, super.key});
  final AppController controller;
  @override State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  late Future<_CompanyData> _data;
  bool _working = false;
  bool get _isAdmin => widget.controller.session?.user.role.toUpperCase() == 'ADMINISTRADOR';

  @override void initState() { super.initState(); _reload(); }
  void _reload() => _data = _fetch();
  Future<_CompanyData> _fetch() async {
    final company = await widget.controller.companyApi.getCompany();
    final users = await widget.controller.companyApi.users();
    var audit = <Map<String, dynamic>>[];
    if (_isAdmin) {
      try { audit = await widget.controller.companyApi.audit(limit: 30); } catch (_) {}
    }
    return _CompanyData(company, users, audit);
  }
  Future<void> _refresh() async {
    final nextData = _fetch();
    if (mounted) {
      setState(() {
        _data = nextData;
      });
    }
    await nextData;
  }
  void _message(String text, {bool error = false}) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? SteelColors.danger : SteelColors.success)); }

  Future<void> _editCompany(Company company) async {
    final successMessage = AppStrings.of(context).get('companyUpdated');
    final result = await showDialog<_CompanyFormResult>(context: context, builder: (_) => _CompanyDialog(company: company));
    if (result == null) return;
    await _run(() async {
      await widget.controller.companyApi.updateCompany(
        name: result.name,
        cnpj: result.cnpj,
        email: result.email,
        phone: result.phone,
        address: result.address,
        number: result.number,
        district: result.district,
        city: result.city,
        state: result.state,
        zipCode: result.zipCode,
        country: result.country,
        website: result.website,
      );
      _message(successMessage);
      await _refresh();
    });
  }

  Future<void> _changeLogo() async {
    if (!_isAdmin || _working) return;
    final strings = AppStrings.of(context);
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    if (picked == null) return;

    final extension = picked.path.split('.').last.toLowerCase();
    if (!const {'png', 'jpg', 'jpeg', 'webp'}.contains(extension)) {
      _message(strings.get('invalidLogoFormat'), error: true);
      return;
    }

    await _run(() async {
      await widget.controller.companyApi.uploadLogo(File(picked.path));
      _message(strings.get('logoUpdated'));
      await _refresh();
    });
  }

  Future<void> _removeLogo() async {
    if (!_isAdmin || _working) return;
    final strings = AppStrings.of(context);
    final confirmed = await _confirm(
      title: strings.get('removeLogoTitle'),
      message: strings.get('removeLogoMessage'),
      action: strings.get('removeLogo'),
    );
    if (!confirmed) return;

    await _run(() async {
      await widget.controller.companyApi.removeLogo();
      _message(strings.get('logoRemoved'));
      await _refresh();
    });
  }

  Widget _companyHero(Company company, AppStrings strings) {
    final logo = CompanyLogo(
      company: company,
      token: widget.controller.session?.token,
      size: 86,
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          company.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'CNPJ: ${formatCnpj(company.cnpj)}',
          style: const TextStyle(color: SteelColors.muted),
        ),
        const SizedBox(height: 8),
        Chip(
          avatar: const Icon(Icons.circle, size: 9, color: SteelColors.success),
          label: Text(strings.get('activeCompany')),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _working ? null : _changeLogo,
          icon: const Icon(Icons.photo_camera_back_outlined),
          label: Text(strings.get('changeLogo')),
        ),
        OutlinedButton.icon(
          onPressed: _working || company.logoUrl?.trim().isNotEmpty != true ? null : _removeLogo,
          style: OutlinedButton.styleFrom(foregroundColor: SteelColors.danger),
          icon: const Icon(Icons.delete_outline_rounded),
          label: Text(strings.get('removeLogo')),
        ),
      ],
    );

    return SectionCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [logo, const SizedBox(width: 17), Expanded(child: info)]),
                if (_isAdmin) ...[
                  const SizedBox(height: 14),
                  actions,
                  const SizedBox(height: 5),
                  Text(strings.get('logoFormatHint'), style: const TextStyle(color: SteelColors.muted, fontSize: 11)),
                ],
              ],
            );
          }

          return Row(
            children: [
              logo,
              const SizedBox(width: 17),
              Expanded(child: info),
              if (_isAdmin) ...[
                const SizedBox(width: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      actions,
                      const SizedBox(height: 5),
                      Text(
                        strings.get('logoFormatHint'),
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: SteelColors.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _createUser() async {
    final successMessage = AppStrings.of(context).get('employeeCreated');
    final result = await showDialog<_UserFormResult>(context: context, builder: (_) => const _UserDialog());
    if (result == null) return;
    await _run(() async { await widget.controller.companyApi.createUser(name: result.name, email: result.email, password: result.password ?? '', role: result.role); _message(successMessage); await _refresh(); });
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final successMessage = AppStrings.of(context).get('accessUpdated');
    final result = await showDialog<_UserFormResult>(context: context, builder: (_) => _UserDialog(user: user));
    if (result == null) return;
    await _run(() async {
      final id = _asInt(user['id']);
      final currentEmail = '${user['email'] ?? ''}';
      final ownAccount = id == widget.controller.session?.user.id;
      final emailChanged = result.email.trim().toLowerCase() != currentEmail.trim().toLowerCase();
      if (ownAccount && emailChanged) {
        await widget.controller.companyApi.updateUser(id, name: result.name, email: currentEmail, role: result.role, password: result.password);
        await widget.controller.companyApi.requestEmailChange(id, result.email);
        if (!mounted) return;
        final code = await showDialog<String>(context: context, builder: (_) => _CodeDialog(email: result.email));
        if (code == null) return;
        await widget.controller.companyApi.confirmEmailChange(id, result.email, code);
      } else {
        await widget.controller.companyApi.updateUser(id, name: result.name, email: result.email, role: result.role, password: result.password);
      }
      _message(successMessage); await _refresh();
    });
  }

  Future<void> _dismissUser(Map<String, dynamic> user) async {
    final strings = AppStrings.of(context);
    if (_asInt(user['id']) == widget.controller.session?.user.id) { _message(strings.get('cannotDismissSelf'), error: true); return; }
    final confirmed = await _confirm(title: strings.get('dismissEmployeeTitle'), message: strings.get('dismissEmployeeMessage').replaceAll('{name}', '${user['nome']}'), action: strings.get('dismissEmployee'));
    if (!confirmed) return;
    await _run(() async { await widget.controller.companyApi.dismissUser(_asInt(user['id'])); _message(strings.get('employeeDismissed')); await _refresh(); });
  }

  Future<void> _registerFace(Map<String, dynamic> user) async {
    final strings = AppStrings.of(context);
    if (user['facialCadastrada'] == true || _asInt(user['quantidadeFaces']) > 0) { _message(strings.get('faceAlreadyRegistered'), error: true); return; }
    final completed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => FaceAuthScreen(controller: widget.controller, userId: _asInt(user['id']))));
    if (completed == true) { _message(strings.get('faceLinked').replaceAll('{name}', '${user['nome']}')); await _refresh(); }
  }

  Future<void> _manageFaces(Map<String, dynamic> user) async {
    await _run(() async {
      final faces = await widget.controller.companyApi.faces(_asInt(user['id']));
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text('${AppStrings.of(dialogContext).get('withBiometrics')}: ${user['nome']}'),
        content: SizedBox(width: 520, child: faces.isEmpty ? Text(AppStrings.of(dialogContext).get('noFaceProfile')) : Column(mainAxisSize: MainAxisSize.min, children: faces.map((face) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.face_retouching_natural_rounded)), title: Text('${face['nome'] ?? AppStrings.of(dialogContext).get('primaryFace')}'), subtitle: Text(_date(face['criadoEm'])),
          trailing: IconButton(tooltip: AppStrings.of(dialogContext).get('removeFace'), icon: const Icon(Icons.delete_outline_rounded, color: SteelColors.danger), onPressed: () async {
            final strings = AppStrings.of(dialogContext);
            final ok = await _confirm(context: dialogContext, title: strings.get('removeFaceTitle'), message: strings.get('removeFaceMessage'), action: strings.get('remove'));
            if (!ok) return;
            try { await widget.controller.companyApi.removeFace(_asInt(user['id']), _asInt(face['id'])); if (dialogContext.mounted) Navigator.pop(dialogContext); _message(strings.get('faceRemoved')); await _refresh(); } on ApiException catch (e) { _message(e.message, error: true); }
          }),
        )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(AppStrings.of(dialogContext).get('close')))],
      ));
    });
  }

  Future<bool> _confirm({BuildContext? context, required String title, required String message, required String action}) async => await showDialog<bool>(context: context ?? this.context, builder: (ctx) => AlertDialog(icon: const Icon(Icons.warning_amber_rounded, color: SteelColors.warning, size: 38), title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.of(ctx).get('cancel'))), FilledButton(style: FilledButton.styleFrom(backgroundColor: SteelColors.danger), onPressed: () => Navigator.pop(ctx, true), child: Text(action))])) ?? false;
  Future<void> _run(Future<void> Function() operation) async { if (_working) return; setState(() => _working = true); try { await operation(); } on ApiException catch (e) { _message(e.message, error: true); } catch (e) { _message('$e', error: true); } finally { if (mounted) setState(() => _working = false); } }

  @override Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return FutureBuilder<_CompanyData>(future: _data, builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
    if (snapshot.hasError) return Center(child: FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: Text('${snapshot.error}')));
    final data = snapshot.data!;
    final location = [data.company.address, data.company.number, data.company.district, data.company.city, data.company.state, data.company.zipCode, data.company.country].where((item) => item?.trim().isNotEmpty == true).join(' • ');
    return RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.all(22), children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.get('company'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(strings.get('companyTeamCaption'), style: const TextStyle(color: SteelColors.muted))])), if (_isAdmin) ...[OutlinedButton.icon(onPressed: _working ? null : () => _editCompany(data.company), icon: const Icon(Icons.edit_outlined), label: Text(strings.get('editCompany'))), const SizedBox(width: 9), FilledButton.icon(onPressed: _working ? null : _createUser, icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(strings.get('newEmployee')))] ]),
      const SizedBox(height: 18),
      _companyHero(data.company, strings),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, constraints) => GridView.count(crossAxisCount: constraints.maxWidth >= 680 ? 2 : 1, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, mainAxisExtent: 124, children: [MetricCard(label: strings.get('activeEmployees'), value: '${data.users.length}', icon: Icons.groups_outlined, color: SteelColors.primary), MetricCard(label: strings.get('withBiometrics'), value: '${data.users.where((u) => u['facialCadastrada'] == true || _asInt(u['quantidadeFaces']) > 0).length}', icon: Icons.face_retouching_natural_rounded, color: SteelColors.success)])),
      const SizedBox(height: 14),
      SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.get('institutionalInfo'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 16), _InfoRow(icon: Icons.mail_outline, label: strings.get('email'), value: data.company.email ?? '-'), _InfoRow(icon: Icons.phone_outlined, label: strings.get('phone'), value: data.company.phone ?? '-'), _InfoRow(icon: Icons.location_on_outlined, label: strings.get('location'), value: location.isEmpty ? strings.get('notProvided') : location), if (data.company.website?.isNotEmpty == true) _InfoRow(icon: Icons.language_rounded, label: strings.get('website'), value: data.company.website!)])),
      const SizedBox(height: 14),
      SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(strings.get('teamAccess'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), if (_working) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))]), const SizedBox(height: 8), ...data.users.map((user) => _UserTile(user: user, admin: _isAdmin, currentUserId: widget.controller.session?.user.id, onEdit: () => _editUser(user), onDismiss: () => _dismissUser(user), onRegisterFace: () => _registerFace(user), onFaces: () => _manageFaces(user)))])),
      if (data.audit.isNotEmpty) ...[const SizedBox(height: 14), SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.get('recentAudit'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 8), ...data.audit.take(10).map((item) { final actor = item['usuario'] is Map ? item['usuario'] as Map : const {}; return ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.verified_user_outlined, color: SteelColors.primary), title: Text('${_auditPreviewAction(strings, item['acao'])} • ${_auditPreviewEntity(strings, item['entidade'])}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${actor['nome'] ?? actor['email'] ?? strings.get('system')}'), trailing: Text(_date(item['criadoEm']), style: const TextStyle(color: SteelColors.muted, fontSize: 11))); })]))],
    ]));
  });
  }
}

class _CompanyDialog extends StatefulWidget {
  const _CompanyDialog({required this.company});
  final Company company;
  @override State<_CompanyDialog> createState() => _CompanyDialogState();
}

class _CompanyDialogState extends State<_CompanyDialog> {
  final key = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    final company = widget.company;
    final values = <String, String?>{'name': company.name, 'cnpj': formatCnpj(company.cnpj), 'email': company.email, 'phone': company.phone, 'address': company.address, 'number': company.number, 'district': company.district, 'city': company.city, 'state': company.state, 'zipCode': company.zipCode, 'country': company.country, 'website': company.website};
    for (final entry in values.entries) { fields[entry.key] = TextEditingController(text: entry.value ?? ''); }
  }

  @override
  void dispose() { for (final controller in fields.values) { controller.dispose(); } super.dispose(); }

  Widget input(String name, String label, {bool required = false, TextInputType? type, List<TextInputFormatter>? formatters}) => TextFormField(controller: fields[name], keyboardType: type, inputFormatters: formatters, decoration: InputDecoration(labelText: label), validator: required ? (value) => value?.trim().isNotEmpty == true ? null : AppStrings.of(context).get('requiredField') : null);

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(strings.get('editCompany')),
      content: SizedBox(width: 650, child: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        input('name', strings.get('companyName'), required: true), const SizedBox(height: 12),
        input('cnpj', 'CNPJ', required: true, type: TextInputType.number, formatters: [CnpjInputFormatter()]), const SizedBox(height: 12),
        Row(children: [Expanded(child: input('email', strings.get('email'), type: TextInputType.emailAddress)), const SizedBox(width: 12), Expanded(child: input('phone', strings.get('phone'), type: TextInputType.phone))]), const SizedBox(height: 12),
        Row(children: [Expanded(flex: 3, child: input('address', strings.get('address'))), const SizedBox(width: 12), Expanded(child: input('number', strings.get('number')))]), const SizedBox(height: 12),
        Row(children: [Expanded(child: input('district', strings.get('district'))), const SizedBox(width: 12), Expanded(child: input('city', strings.get('city')))]), const SizedBox(height: 12),
        Row(children: [Expanded(child: input('state', strings.get('state'))), const SizedBox(width: 12), Expanded(child: input('zipCode', strings.get('zipCode')))]), const SizedBox(height: 12),
        Row(children: [Expanded(child: input('country', strings.get('country'))), const SizedBox(width: 12), Expanded(child: input('website', strings.get('website'), type: TextInputType.url))]),
      ])))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(strings.get('cancel'))), FilledButton.icon(onPressed: () { if (!key.currentState!.validate()) return; Navigator.pop(context, _CompanyFormResult.from(fields)); }, icon: const Icon(Icons.save_outlined), label: Text(strings.get('save')))],
    );
  }
}

class _CompanyFormResult {
  const _CompanyFormResult({required this.name, required this.cnpj, required this.email, required this.phone, required this.address, required this.number, required this.district, required this.city, required this.state, required this.zipCode, required this.country, required this.website});
  final String name, cnpj, email, phone, address, number, district, city, state, zipCode, country, website;
  factory _CompanyFormResult.from(Map<String, TextEditingController> fields) => _CompanyFormResult(name: fields['name']!.text, cnpj: fields['cnpj']!.text, email: fields['email']!.text, phone: fields['phone']!.text, address: fields['address']!.text, number: fields['number']!.text, district: fields['district']!.text, city: fields['city']!.text, state: fields['state']!.text, zipCode: fields['zipCode']!.text, country: fields['country']!.text, website: fields['website']!.text);
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.admin, required this.currentUserId, required this.onEdit, required this.onDismiss, required this.onRegisterFace, required this.onFaces});
  final Map<String, dynamic> user; final bool admin; final int? currentUserId; final VoidCallback onEdit; final VoidCallback onDismiss; final VoidCallback onRegisterFace; final VoidCallback onFaces;
  @override Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final hasFace = user['facialCadastrada'] == true || _asInt(user['quantidadeFaces']) > 0;
    final own = _asInt(user['id']) == currentUserId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .32), border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(17)),
      child: Row(children: [
        Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE0ECFF), Color(0xFFF0F5FF)]), borderRadius: BorderRadius.circular(14)), child: Text(_initial('${user['nome'] ?? 'U'}'), style: const TextStyle(color: SteelColors.primary, fontWeight: FontWeight.w900, fontSize: 16))),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Flexible(child: Text('${user['nome'] ?? strings.get('notProvided')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))), if (own) Padding(padding: const EdgeInsets.only(left: 8), child: _MiniBadge(label: strings.get('you'), color: SteelColors.primary, icon: Icons.person_rounded))]),
          const SizedBox(height: 3),
          Text('${user['email'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SteelColors.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 6, children: [
            _MiniBadge(label: _roleLabel(strings, '${user['cargo'] ?? user['cargoTela'] ?? ''}').toUpperCase(), color: SteelColors.primary, icon: Icons.badge_outlined),
            _MiniBadge(label: hasFace ? strings.get('activeBiometrics') : strings.get('noBiometrics'), color: hasFace ? SteelColors.success : SteelColors.warning, icon: hasFace ? Icons.verified_user_rounded : Icons.face_retouching_off_rounded),
          ]),
        ])),
        if (admin) PopupMenuButton<String>(tooltip: strings.get('manageEmployee'), icon: const Icon(Icons.more_horiz_rounded), onSelected: (value) { if (value == 'edit') onEdit(); if (value == 'face') onRegisterFace(); if (value == 'faces') onFaces(); if (value == 'dismiss') onDismiss(); }, itemBuilder: (_) => [PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.manage_accounts_outlined), title: Text(strings.get('editLoginRole')))), if (!hasFace) PopupMenuItem(value: 'face', child: ListTile(leading: const Icon(Icons.face_retouching_natural_rounded), title: Text(strings.get('faceRegister')))) else PopupMenuItem(value: 'faces', child: ListTile(leading: const Icon(Icons.shield_outlined), title: Text(strings.get('manageFace')))), if (!own) const PopupMenuDivider(), if (!own) PopupMenuItem(value: 'dismiss', child: ListTile(textColor: SteelColors.danger, iconColor: SteelColors.danger, leading: const Icon(Icons.person_remove_outlined), title: Text(strings.get('dismissEmployee'))))]) else Icon(hasFace ? Icons.verified_user_rounded : Icons.person_outline, color: hasFace ? SteelColors.success : SteelColors.muted),
      ]),
    );
  }
}

class _MiniBadge extends StatelessWidget { const _MiniBadge({required this.label,required this.color,required this.icon}); final String label; final Color color; final IconData icon; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),decoration:BoxDecoration(color:color.withValues(alpha:.09),border:Border.all(color:color.withValues(alpha:.16)),borderRadius:BorderRadius.circular(99)),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:12,color:color),const SizedBox(width:5),Text(label,style:TextStyle(color:color,fontSize:9,fontWeight:FontWeight.w800,letterSpacing:.25))])); }

class _UserDialog extends StatefulWidget { const _UserDialog({this.user}); final Map<String, dynamic>? user; @override State<_UserDialog> createState() => _UserDialogState(); }
class _UserDialogState extends State<_UserDialog> {
  final key = GlobalKey<FormState>(); late final TextEditingController name; late final TextEditingController email; final password = TextEditingController(); late String role; bool get editing => widget.user != null;
  @override void initState() { super.initState(); name = TextEditingController(text: '${widget.user?['nome'] ?? ''}'); email = TextEditingController(text: '${widget.user?['email'] ?? ''}'); role = '${widget.user?['cargo'] ?? 'OPERADOR'}'; }
  @override void dispose() { name.dispose(); email.dispose(); password.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { final strings = AppStrings.of(context); return AlertDialog(title: Text(editing ? strings.get('editAccess') : strings.get('registerEmployee')), content: SizedBox(width: 520, child: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextFormField(controller: name, decoration: InputDecoration(labelText: strings.get('fullName'), prefixIcon: const Icon(Icons.person_outline)), validator: _required), const SizedBox(height: 12), TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: strings.get('accessEmail'), prefixIcon: const Icon(Icons.mail_outline)), validator: (v) => v?.contains('@') == true ? null : strings.get('validEmail')), const SizedBox(height: 12), DropdownButtonFormField<String>(initialValue: role, decoration: InputDecoration(labelText: strings.get('role'), prefixIcon: const Icon(Icons.badge_outlined)), items: const ['ADMINISTRADOR','SUPERVISOR','TECNICO','OPERADOR','VISITANTE'].map((r) => DropdownMenuItem(value: r, child: Text(_roleLabel(strings, r)))).toList(), onChanged: (v) => role = v!), const SizedBox(height: 12), TextFormField(controller: password, obscureText: true, decoration: InputDecoration(labelText: editing ? strings.get('newPasswordOptional') : strings.get('initialPassword'), prefixIcon: const Icon(Icons.lock_outline)), validator: (v) => !editing && (v?.length ?? 0) < 8 ? strings.get('minimumPassword') : (editing && v!.isNotEmpty && v.length < 8 ? strings.get('minimumPassword') : null))])))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(strings.get('cancel'))), FilledButton(onPressed: () { if (!key.currentState!.validate()) return; Navigator.pop(context, _UserFormResult(name.text, email.text, password.text.isEmpty ? null : password.text, role)); }, child: Text(editing ? strings.get('saveChanges') : strings.get('register')))]); }
  String? _required(String? v) => v?.trim().isNotEmpty == true ? null : AppStrings.of(context).get('requiredField');
}

class _CodeDialog extends StatefulWidget { const _CodeDialog({required this.email}); final String email; @override State<_CodeDialog> createState() => _CodeDialogState(); }
class _CodeDialogState extends State<_CodeDialog> { final code = TextEditingController(); @override void dispose(){code.dispose(); super.dispose();} @override Widget build(BuildContext context) { final strings = AppStrings.of(context); return AlertDialog(icon: const Icon(Icons.mark_email_read_outlined, color: SteelColors.primary, size: 38), title: Text(strings.get('confirmNewEmail')), content: Column(mainAxisSize: MainAxisSize.min, children: [Text('${strings.get('codeSent')} ${widget.email}'), const SizedBox(height: 16), TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, decoration: InputDecoration(labelText: strings.get('sixDigitCode'), counterText: ''))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(strings.get('cancel'))), FilledButton(onPressed: () => code.text.length == 6 ? Navigator.pop(context, code.text) : null, child: Text(strings.get('confirm')))]); } }

class _UserFormResult { const _UserFormResult(this.name, this.email, this.password, this.role); final String name; final String email; final String? password; final String role; }
class _CompanyData { const _CompanyData(this.company, this.users, this.audit); final Company company; final List<Map<String, dynamic>> users; final List<Map<String, dynamic>> audit; }
class _InfoRow extends StatelessWidget { const _InfoRow({required this.icon, required this.label, required this.value}); final IconData icon; final String label; final String value; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 13), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: SteelColors.primary, size: 21), const SizedBox(width: 12), SizedBox(width: 90, child: Text(label, style: const TextStyle(color: SteelColors.muted))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)))])); }
int _asInt(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
String _initial(String value) => value.trim().isEmpty ? 'U' : value.trim().substring(0, 1).toUpperCase();
String _roleLabel(AppStrings strings, String value) => switch (value.toUpperCase()) { 'ADMINISTRADOR' => strings.get('roleAdministrator'), 'SUPERVISOR' => strings.get('roleSupervisor'), 'TECNICO' || 'TÉCNICO' => strings.get('roleTechnician'), 'OPERADOR' => strings.get('roleOperator'), 'VISITANTE' => strings.get('roleVisitor'), _ => value };

String _auditPreviewAction(AppStrings strings, dynamic raw) {
  final value = '${raw ?? ''}'.toUpperCase();
  return switch (value) {
    'CRIAR' => strings.get('auditCreate'),
    'ATUALIZAR' => strings.get('auditUpdate'),
    'DESATIVAR' => strings.get('auditDisable'),
    'REMOVER' => strings.get('auditRemove'),
    'ATUALIZAR_LOGO' => strings.get('auditUpdateLogo'),
    'REMOVER_LOGO' => strings.get('auditRemoveLogo'),
    'LOGIN' => strings.get('auditLogin'),
    'LOGIN_FACIAL' => strings.get('auditFaceLogin'),
    'CADASTRAR_FACE' => strings.get('auditFaceRegister'),
    'REMOVER_FACE' => strings.get('auditFaceRemove'),
    _ => value.isEmpty ? strings.get('audit') : value.replaceAll('_', ' '),
  };
}

String _auditPreviewEntity(AppStrings strings, dynamic raw) {
  final value = '${raw ?? ''}'.toUpperCase();
  return switch (value) {
    'EMPRESA' => strings.get('auditCompany'),
    'USUARIO' || 'USUÁRIO' => strings.get('auditUser'),
    'MAQUINA' || 'MÁQUINA' => strings.get('auditMachine'),
    'MANUTENCAO' || 'MANUTENÇÃO' => strings.get('auditMaintenance'),
    'FACE' || 'FACIAL' => strings.get('auditFace'),
    'AUTENTICACAO' || 'AUTENTICAÇÃO' => strings.get('auditAuthentication'),
    'COMANDO' => strings.get('auditCommandEntity'),
    'SISTEMA' || '' => strings.get('system'),
    _ => value.replaceAll('_', ' '),
  };
}

String _date(dynamic value) { final date = DateTime.tryParse('$value')?.toLocal(); if (date == null) return '-'; String two(int n) => n.toString().padLeft(2, '0'); return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}'; }
