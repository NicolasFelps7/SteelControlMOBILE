import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../core/app_theme.dart';
import '../state/app_controller.dart';
import '../widgets/steel_brand.dart';
import '../widgets/logout_confirmation.dart';
import 'audit_screen.dart';
import 'company_screen.dart';
import 'machine_dashboard_screen.dart';
import 'machines_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcome());
  }

  Future<void> _showWelcome() async {
    final notice = widget.controller.consumeWelcome();
    if (!mounted || notice == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AccessWelcomeDialog(notice: notice),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final selected = widget.controller.selectedMachine;
    final admin = widget.controller.session?.user.role.toUpperCase() == 'ADMINISTRADOR';
    final selectedName = selected == null
        ? ''
        : (selected.name.trim().isNotEmpty ? selected.name.trim() : 'Máquina #${selected.id}');
    final selectedMeta = selected == null
        ? ''
        : (selected.sector.trim().isNotEmpty && selected.sector.trim() != '-'
            ? selected.sector.trim()
            : ((selected.controller ?? '').trim().isNotEmpty
                ? selected.controller!.trim()
                : selected.model.trim()));
    final items = selected == null
        ? <_Destination>[
            _Destination(strings.get('machines'), Icons.precision_manufacturing_outlined, 0),
            _Destination(strings.get('company'), Icons.apartment_rounded, 1),
            if (admin) _Destination(strings.get('audit'), Icons.policy_outlined, 2),
            _Destination(strings.get('settings'), Icons.settings_outlined, 3),
          ]
        : <_Destination>[
            _Destination(strings.get('overview'), Icons.dashboard_outlined, 0),
            _Destination(strings.get('production'), Icons.analytics_outlined, 1),
            _Destination(strings.get('maintenance'), Icons.build_outlined, 2),
            if (admin) _Destination(strings.get('logs'), Icons.receipt_long_outlined, 3),
            _Destination(strings.get('alerts'), Icons.notifications_none_rounded, 4),
            _Destination(strings.get('settings'), Icons.settings_outlined, -1),
          ];

    if (_index >= items.length) _index = 0;

    final body = selected == null
        ? switch (items[_index].section) {
            1 => CompanyScreen(controller: widget.controller),
            2 => AuditScreen(controller: widget.controller),
            3 => SettingsScreen(
                controller: widget.controller,
                onOpenCompany: () => setState(() => _index = 1),
              ),
            _ => MachinesScreen(
                controller: widget.controller,
                onSelected: () => setState(() => _index = 0),
              ),
          }
        : items[_index].section == -1
            ? SettingsScreen(controller: widget.controller, onOpenCompany: () {
                setState(() => _index = 1);
                widget.controller.clearSelectedMachine();
              })
            : MachineDashboardScreen(
                controller: widget.controller,
                section: items[_index].section,
              );

    return LayoutBuilder(
      builder: (context, constraints) {
        final tablet = constraints.maxWidth >= 760;

        if (!tablet) {
          return Scaffold(
            appBar: AppBar(
              title: selected == null
                  ? const SteelBrand()
                  : Text(selected.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              leading: selected == null
                  ? null
                  : IconButton(
                      onPressed: () {
                        setState(() => _index = 0);
                        widget.controller.clearSelectedMachine();
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
              actions: [
                IconButton(onPressed: () => _refresh(selected != null), icon: const Icon(Icons.refresh_rounded)),
              ],
            ),
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: items
                  .map((item) => NavigationDestination(icon: Icon(item.icon), label: item.label))
                  .toList(),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                Container(
                  width: 248,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SteelColors.graphite,
                    border: Border.all(color: const Color(0xFF2B353B)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 22, 16, 14),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: SteelBrand(light: true),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Container(height: 1, color: const Color(0xFF344047)),
                      ),
                      if (selected != null) ...[
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 94),
                            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B2429),
                              border: Border.all(color: const Color(0xFF344047)),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF232E34),
                                    border: Border.all(color: const Color(0xFF3C494F)),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const Icon(
                                    Icons.precision_manufacturing_outlined,
                                    size: 18,
                                    color: Color(0xFFFFB84D),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        strings.get('selectedMachine'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF9DA9AF),
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: .75,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        selectedName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          height: 1.08,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -.2,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: selected.isOnline
                                                  ? const Color(0xFF5DB27B)
                                                  : const Color(0xFF7D898F),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              selectedMeta,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFFB2BDC2),
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: items.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Material(
                              color: _index == index ? const Color(0xFF252E33) : const Color(0xFF151D21),
                              borderRadius: BorderRadius.circular(7),
                              child: ListTile(
                                iconColor: _index == index ? const Color(0xFFFFB84D) : const Color(0xFFB5BFC4),
                                textColor: _index == index ? Colors.white : const Color(0xFFD8DEE1),
                                shape: RoundedRectangleBorder(
                                  side: _index == index ? const BorderSide(color: Color(0xFF384249)) : BorderSide.none,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                leading: Icon(items[index].icon),
                                title: Text(items[index].label, style: const TextStyle(fontWeight: FontWeight.w700)),
                                onTap: () => setState(() => _index = index),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (selected != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Material(
                            color: const Color(0xFF151D21),
                            child: ListTile(
                              leading: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFB5BFC4)),
                              title: Text(strings.get('switchMachine'), style: const TextStyle(color: Color(0xFFD8DEE1), fontWeight: FontWeight.w600)),
                              onTap: () {
                                setState(() => _index = 0);
                                widget.controller.clearSelectedMachine();
                              },
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            textColor: const Color(0xFFFF7D7D),
                            iconColor: const Color(0xFFFF7D7D),
                            leading: const Icon(Icons.logout_rounded),
                            title: Text(strings.get('logout'), style: const TextStyle(fontWeight: FontWeight.w700)),
                            onTap: () async {
                              if (await confirmLogout(context) && mounted) {
                                await widget.controller.logout();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 14, 22, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(selected?.name ?? strings.get('centralMachines'), style: Theme.of(context).textTheme.headlineSmall),
                                  Text(selected == null ? strings.get('selectEquipment') : '${selected.controller ?? selected.model} • ${selected.isOnline ? strings.get('online') : strings.get('offline')}', style: const TextStyle(color: SteelColors.muted)),
                                ],
                              ),
                            ),
                            _UserBadge(controller: widget.controller),
                            const SizedBox(width: 10),
                            IconButton.filledTonal(onPressed: () => _refresh(selected != null), icon: const Icon(Icons.refresh_rounded)),
                          ],
                        ),
                      ),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _refresh(bool machine) async {
    try {
      if (machine) {
        await widget.controller.refreshSelectedMachine();
      } else {
        await widget.controller.loadMachines();
        if (mounted) setState(() {});
      }
    } catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$exception')));
    }
  }
}

class _AccessWelcomeDialog extends StatefulWidget {
  const _AccessWelcomeDialog({required this.notice});

  final WelcomeNotice notice;

  @override
  State<_AccessWelcomeDialog> createState() => _AccessWelcomeDialogState();
}

class _AccessWelcomeDialogState extends State<_AccessWelcomeDialog> {
  Timer? _closeTimer;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _progress = 1);
      _closeTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) Navigator.of(context).pop();
      });
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final titleKey = widget.notice.newAccount ? 'welcomeCreatedName' : 'welcomeBackName';
    final captionKey = widget.notice.newAccount ? 'registerSuccessCaption' : 'loginSuccessCaption';
    final title = strings.get(titleKey).replaceAll('{name}', widget.notice.name);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 470),
        padding: const EdgeInsets.fromLTRB(30, 28, 30, 30),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF20272F) : Colors.white,
          border: Border.all(color: dark ? const Color(0xFF3D4854) : const Color(0xFFDDE3E8)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? .35 : .14), blurRadius: 32, offset: const Offset(0, 16))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SteelBrand(light: dark),
            const SizedBox(height: 24),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(color: const Color(0xFFD9FBE7), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: .22), width: 7)),
              child: const Icon(Icons.check_rounded, color: Color(0xFF0AA34F), size: 39),
            ),
            const SizedBox(height: 23),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.14, letterSpacing: -.55)),
            const SizedBox(height: 12),
            Text(strings.get(captionKey), textAlign: TextAlign.center, style: const TextStyle(color: SteelColors.muted, height: 1.55)),
            const SizedBox(height: 26),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _progress),
              duration: const Duration(milliseconds: 1800),
              curve: Curves.easeInOut,
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: value, minHeight: 5, backgroundColor: dark ? const Color(0xFF3D4854) : const Color(0xFFDDE3E8)),
              ),
            ),
            const SizedBox(height: 10),
            Text(strings.get('openingWorkspace'), style: const TextStyle(color: SteelColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.section);
  final String label;
  final IconData icon;
  final int section;
}

class _UserBadge extends StatelessWidget {
  const _UserBadge({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(radius: 15, backgroundColor: SteelColors.primary, child: Icon(Icons.person, color: Colors.white, size: 18)),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.session?.user.name ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                Text(controller.session?.user.role ?? '', style: const TextStyle(color: SteelColors.muted, fontSize: 10)),
              ],
            ),
          ],
        ),
      );
}
