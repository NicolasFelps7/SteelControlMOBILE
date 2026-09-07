import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_strings.dart';
import '../core/app_theme.dart';
import '../models/machine.dart';
import '../services/api_client.dart';
import '../state/app_controller.dart';
import 'section_card.dart';

class IndustrialHmiPanel extends StatefulWidget {
  const IndustrialHmiPanel({
    required this.controller,
    required this.machine,
    super.key,
  });

  final AppController controller;
  final Machine machine;

  @override
  State<IndustrialHmiPanel> createState() => _IndustrialHmiPanelState();
}

class _IndustrialHmiPanelState extends State<IndustrialHmiPanel> {
  Map<String, dynamic> _diagnostics = const {};
  Timer? _timer;
  bool _loading = true;
  bool _commandBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
  }

  @override
  void didUpdateWidget(covariant IndustrialHmiPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.machine.id != widget.machine.id) {
      _diagnostics = const {};
      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await widget.controller.machinesApi.diagnostics(widget.machine.id);
      if (!mounted) return;
      setState(() {
        _diagnostics = result;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = exception.message;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$exception';
      });
    }
  }

  Future<void> _send(String command) async {
    final strings = AppStrings.of(context);
    if (_commandBusy) return;

    if (command == 'IHM_START' && !widget.machine.simulation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.get('hmiConfirmRealStartTitle')),
          content: Text(strings.get('hmiConfirmRealStartMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(strings.get('cancel')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(strings.get('hmiConfirmStart')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _commandBusy = true);
    try {
      final response = await widget.controller.machinesApi.sendHmiCommand(
        widget.machine.id,
        command,
      );

      final machineJson = response['maquina'];
      if (machineJson is Map) {
        widget.controller.replaceSelectedMachine(
          Machine.fromJson(Map<String, dynamic>.from(machineJson)),
        );
      } else {
        try {
          await widget.controller.refreshSelectedMachine();
        } catch (_) {
          // A confirmação do comando já foi recebida; falha de refresh não o desfaz.
        }
      }

      await _load(silent: true);
      if (!mounted) return;
      final message = '${response['mensagem'] ?? strings.get('hmiCommandAccepted')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on ApiException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(exception.message)),
      );
      await _load(silent: true);
    } finally {
      if (mounted) setState(() => _commandBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hmi = _map(_diagnostics['hmi']);
    final connection = _map(_diagnostics['estadoConexao']);
    final extras = _map(_diagnostics['dadosExtras']);
    final telemetryHmi = _map(extras['hmi']);

    final hasDiagnostics = _diagnostics.isNotEmpty;
    final simulation = _diagnostics.containsKey('modoSimulacao')
        ? _diagnostics['modoSimulacao'] == true
        : widget.machine.simulation;
    final running = _boolFirst([
      hmi['running'],
      telemetryHmi['running'],
      widget.machine.status.toLowerCase() == 'ligada',
    ]);
    final mode = '${hmi['mode'] ?? telemetryHmi['mode'] ?? 'AUTO'}'.toUpperCase();
    final alarm = hmi['alarm'] == true || telemetryHmi['alarm'] == true || widget.machine.safetyStop;
    final sensors = _map(hmi['sensors']).isNotEmpty ? _map(hmi['sensors']) : _map(telemetryHmi['sensors']);
    final interlocks = _map(hmi['interlocks']).isNotEmpty
        ? _map(hmi['interlocks'])
        : _map(telemetryHmi['interlocks']);
    final startPolicy = _map(hmi['startPolicy']);
    final remoteEnabled = simulation || hmi['remoteControlEnabled'] == true;
    final connectionCode = '${connection['codigo'] ?? widget.machine.connection}'.toUpperCase();
    final connected = simulation || connectionCode == 'CONECTADA' || connectionCode == 'ONLINE';
    final role = (widget.controller.session?.user.role ?? '').toUpperCase();
    final elevatedRole = role.contains('ADMIN') || role.contains('SUPERVISOR') || role.contains('TECNICO') || role.contains('TÉCNICO');
    final operatorRole = elevatedRole || role.contains('OPERADOR');
    final diagnosticsReady = hasDiagnostics && !_loading && _error == null;
    final commandsBase = diagnosticsReady && remoteEnabled && !_commandBusy;
    final startAllowed = commandsBase && elevatedRole && !running && !alarm && startPolicy['permitido'] == true && connected;
    final stopAllowed = commandsBase && operatorRole;
    final ackAllowed = commandsBase && operatorRole && connected;
    final protectedAllowed = commandsBase && elevatedRole && connected;
    final controllerName = (widget.machine.controller ?? widget.machine.model).replaceAll('_', ' ');
    final pending = _int(_diagnostics['comandosPendentes']);

    String? blockedReason;
    if (!diagnosticsReady) {
      blockedReason = _error ?? strings.get('hmiWaitingDiagnostics');
    } else if (!remoteEnabled) {
      blockedReason = strings.get('hmiRemoteDisabled');
    } else if (!elevatedRole) {
      blockedReason = strings.get('hmiRoleBlocksStart');
    } else if (alarm) {
      blockedReason = strings.get('hmiSafetyBlocked');
    } else if (!connected) {
      blockedReason = strings.get('hmiOfflineBlocksStart');
    } else if (startPolicy['permitido'] != true) {
      blockedReason = '${startPolicy['motivo'] ?? strings.get('hmiStartNotReleased')}';
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            controllerName: controllerName,
            simulation: simulation,
            connected: connected,
            remoteEnabled: remoteEnabled,
            loading: _loading,
            onRefresh: () => _load(),
          ),
          const SizedBox(height: 14),
          _SafetyBanner(
            simulation: simulation,
            remoteEnabled: remoteEnabled,
            alarm: alarm,
            connected: connected,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SteelColors.danger.withValues(alpha: dark ? .14 : .08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: SteelColors.danger.withValues(alpha: .28)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: SteelColors.danger, size: 19),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '${strings.get('hmiDiagnosticsError')}: $_error',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _ProcessConsole(
            running: running,
            alarm: alarm,
            mode: mode,
            sensors: sensors,
            machine: widget.machine,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 4 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 96,
                children: [
                  _Metric(label: strings.get('totalProduction'), value: '${widget.machine.production}', icon: Icons.inventory_2_outlined),
                  _Metric(label: strings.get('cycles'), value: '${widget.machine.cycles}', icon: Icons.sync_rounded),
                  _Metric(label: strings.get('temperature'), value: '${widget.machine.temperature.toStringAsFixed(1)} °C', icon: Icons.thermostat_rounded),
                  _Metric(label: strings.get('vibration'), value: '${widget.machine.vibration.toStringAsFixed(1)} mm/s', icon: Icons.vibration_rounded),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final sensorCard = _StatusGroup(
                title: strings.get('hmiSensors'),
                icon: Icons.sensors_rounded,
                children: [
                  _StatusRow(label: strings.get('hmiSensorEntry'), value: _nullableBool(sensors['entry']), positive: strings.get('hmiDetected'), negative: strings.get('hmiFree')),
                  _StatusRow(label: strings.get('hmiSensorMiddle'), value: _nullableBool(sensors['middle']), positive: strings.get('hmiDetected'), negative: strings.get('hmiFree')),
                  _StatusRow(label: strings.get('hmiSensorExit'), value: _nullableBool(sensors['exit']), positive: strings.get('hmiDetected'), negative: strings.get('hmiFree')),
                ],
              );
              final interlockCard = _StatusGroup(
                title: strings.get('hmiInterlocks'),
                icon: Icons.health_and_safety_outlined,
                children: [
                  _StatusRow(label: strings.get('hmiStartPermitted'), value: _nullableBool(interlocks['startPermitted']), positive: strings.get('hmiReleased'), negative: strings.get('hmiBlocked')),
                  _StatusRow(label: strings.get('hmiEstop'), value: _nullableBool(interlocks['estopOk']), positive: strings.get('hmiSafe'), negative: strings.get('hmiUnsafe')),
                  _StatusRow(label: strings.get('hmiSafetyDoor'), value: _nullableBool(interlocks['safetyDoorClosed']), positive: strings.get('hmiClosed'), negative: strings.get('hmiOpen')),
                  _StatusRow(label: strings.get('hmiGuard'), value: _nullableBool(interlocks['guardOk']), positive: strings.get('hmiSafe'), negative: strings.get('hmiUnsafe')),
                ],
              );
              if (!wide) {
                return Column(children: [sensorCard, const SizedBox(height: 10), interlockCard]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: sensorCard), const SizedBox(width: 10), Expanded(child: interlockCard)],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: dark ? .35 : .55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gamepad_outlined, color: SteelColors.primary),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        strings.get('hmiSupervisedControls'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (pending > 0)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.schedule_rounded, size: 16),
                        label: Text('$pending ${strings.get('hmiPending')}'),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(strings.get('hmiSecureQueueCaption'), style: const TextStyle(color: SteelColors.muted, fontSize: 12)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    _HmiButton(
                      label: strings.get('hmiAuto'),
                      icon: Icons.autorenew_rounded,
                      active: mode == 'AUTO',
                      enabled: protectedAllowed,
                      onPressed: () => _send('IHM_MODE_AUTO'),
                    ),
                    _HmiButton(
                      label: strings.get('hmiManual'),
                      icon: Icons.pan_tool_alt_outlined,
                      active: mode == 'MANUAL',
                      enabled: protectedAllowed,
                      onPressed: () => _send('IHM_MODE_MANUAL'),
                    ),
                    _HmiButton(
                      label: strings.get('hmiStart'),
                      icon: Icons.play_arrow_rounded,
                      enabled: startAllowed,
                      positive: true,
                      onPressed: () => _send('IHM_START'),
                    ),
                    _HmiButton(
                      label: strings.get('hmiStop'),
                      icon: Icons.stop_rounded,
                      enabled: stopAllowed,
                      danger: true,
                      onPressed: () => _send('IHM_STOP'),
                    ),
                    _HmiButton(
                      label: strings.get('hmiReset'),
                      icon: Icons.restart_alt_rounded,
                      enabled: protectedAllowed,
                      onPressed: () => _send('IHM_RESET'),
                    ),
                    _HmiButton(
                      label: strings.get('hmiAck'),
                      icon: Icons.done_all_rounded,
                      enabled: ackAllowed,
                      onPressed: () => _send('IHM_ACK'),
                    ),
                  ],
                ),
                if (blockedReason != null && !startAllowed) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: SteelColors.warning, size: 18),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '${strings.get('hmiStartBlocked')}: $blockedReason',
                          style: const TextStyle(color: SteelColors.muted, fontSize: 11.5, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_commandBusy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 3),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: SteelColors.muted, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  strings.get('hmiStopDisclaimer'),
                  style: const TextStyle(color: SteelColors.muted, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
          if (_diagnostics['ultimaTelemetriaEm'] != null) ...[
            const SizedBox(height: 7),
            Text(
              '${strings.get('hmiLastTelemetry')}: ${_formatDate(_diagnostics['ultimaTelemetriaEm'])}',
              style: const TextStyle(color: SteelColors.muted, fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controllerName,
    required this.simulation,
    required this.connected,
    required this.remoteEnabled,
    required this.loading,
    required this.onRefresh,
  });

  final String controllerName;
  final bool simulation;
  final bool connected;
  final bool remoteEnabled;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [SteelColors.ink, SteelColors.primary]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.developer_board_rounded, color: Colors.white, size: 27),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.get('hmiTitle'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                '$controllerName • ${strings.get('hmiSupervised')}',
                style: const TextStyle(color: SteelColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  _Pill(
                    label: simulation ? strings.get('simulation') : strings.get('real'),
                    icon: simulation ? Icons.science_outlined : Icons.memory_rounded,
                    color: simulation ? SteelColors.primary : SteelColors.success,
                  ),
                  _Pill(
                    label: connected ? strings.get('online') : strings.get('offline'),
                    icon: connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                    color: connected ? SteelColors.success : SteelColors.danger,
                  ),
                  if (!simulation)
                    _Pill(
                      label: remoteEnabled ? strings.get('hmiRemoteOn') : strings.get('hmiRemoteOff'),
                      icon: remoteEnabled ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                      color: remoteEnabled ? SteelColors.success : SteelColors.warning,
                    ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: strings.get('refreshDiagnostics'),
          onPressed: loading ? null : onRefresh,
          icon: loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({
    required this.simulation,
    required this.remoteEnabled,
    required this.alarm,
    required this.connected,
  });

  final bool simulation;
  final bool remoteEnabled;
  final bool alarm;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final (icon, color, text) = alarm
        ? (Icons.warning_amber_rounded, SteelColors.danger, strings.get('hmiSafetyBlocked'))
        : simulation
            ? (Icons.science_outlined, SteelColors.primary, strings.get('hmiSimulationCaption'))
            : !remoteEnabled
                ? (Icons.lock_outline_rounded, SteelColors.warning, strings.get('hmiRemoteDisabled'))
                : !connected
                    ? (Icons.cloud_off_outlined, SteelColors.warning, strings.get('hmiOfflineBlocksStart'))
                    : (Icons.verified_user_outlined, SteelColors.success, strings.get('hmiRealCaption'));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.35, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _ProcessConsole extends StatelessWidget {
  const _ProcessConsole({
    required this.running,
    required this.alarm,
    required this.mode,
    required this.sensors,
    required this.machine,
  });

  final bool running;
  final bool alarm;
  final String mode;
  final Map<String, dynamic> sensors;
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final runText = alarm
        ? strings.get('hmiBlockedState')
        : running
            ? strings.get('hmiRunningState')
            : strings.get('hmiStoppedState');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF11161C), Color(0xFF27313C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.get('hmiProcessView'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              _DarkBadge(label: mode, color: SteelColors.primary),
              const SizedBox(width: 6),
              _DarkBadge(label: runText, color: alarm ? SteelColors.danger : running ? SteelColors.success : SteelColors.warning),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: running && !alarm ? null : 0,
              minHeight: 4,
              backgroundColor: Colors.white12,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 610,
              child: Row(
                children: [
                  _ProcessNode(
                    icon: Icons.login_rounded,
                    title: strings.get('hmiEntry'),
                    subtitle: strings.get('hmiSensorEntry'),
                    active: sensors['entry'] == true,
                  ),
                  _Connector(active: running && !alarm),
                  _ProcessNode(
                    icon: Icons.view_week_rounded,
                    fallbackIcon: Icons.settings_input_component_rounded,
                    title: strings.get('hmiConveyor'),
                    subtitle: running ? strings.get('hmiMoving') : strings.get('hmiStoppedState'),
                    active: running && !alarm,
                  ),
                  _Connector(active: running && !alarm),
                  _ProcessNode(
                    icon: Icons.precision_manufacturing_rounded,
                    title: strings.get('hmiStation'),
                    subtitle: machine.name,
                    active: running && !alarm,
                  ),
                  _Connector(active: running && !alarm),
                  _ProcessNode(
                    icon: Icons.logout_rounded,
                    title: strings.get('hmiExit'),
                    subtitle: strings.get('hmiSensorExit'),
                    active: sensors['exit'] == true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessNode extends StatelessWidget {
  const _ProcessNode({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    this.fallbackIcon,
  });

  final IconData icon;
  final IconData? fallbackIcon;
  final String title;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        width: 118,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF3D4854) : Colors.white.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? const Color(0xFF9AA6B1) : Colors.white12),
        ),
        child: Column(
          children: [
            Icon(_safeIcon(icon, fallbackIcon), color: active ? const Color(0xFFBCC5CD) : Colors.white70, size: 26),
            const SizedBox(height: 7),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 9.5)),
          ],
        ),
      );

  IconData _safeIcon(IconData preferred, IconData? fallback) => fallback ?? preferred;
}

class _Connector extends StatelessWidget {
  const _Connector({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        child: Row(
          children: [
            Expanded(child: Container(height: 2, color: active ? const Color(0xFF9AA6B1) : Colors.white24)),
            Icon(Icons.arrow_forward_ios_rounded, size: 11, color: active ? const Color(0xFF9AA6B1) : Colors.white38),
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .42),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: SteelColors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: SteelColors.primary, size: 21),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SteelColors.muted, fontSize: 10.5)),
                  const SizedBox(height: 2),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _StatusGroup extends StatelessWidget {
  const _StatusGroup({required this.title, required this.icon, required this.children});
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: SteelColors.primary, size: 19), const SizedBox(width: 7), Text(title, style: const TextStyle(fontWeight: FontWeight.w800))]),
            const SizedBox(height: 9),
            ...children,
          ],
        ),
      );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value, required this.positive, required this.negative});
  final String label;
  final bool? value;
  final String positive;
  final String negative;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final color = value == null ? SteelColors.warning : value! ? SteelColors.success : SteelColors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 9),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11.5))),
          Text(value == null ? strings.get('hmiNoData') : value! ? positive : negative, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _HmiButton extends StatelessWidget {
  const _HmiButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.active = false,
    this.positive = false,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final bool active;
  final bool positive;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    if (danger) {
      return FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(backgroundColor: SteelColors.danger, foregroundColor: Colors.white),
        icon: Icon(icon),
        label: Text(label),
      );
    }
    if (positive) {
      return FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(backgroundColor: SteelColors.success, foregroundColor: Colors.white),
        icon: Icon(icon),
        label: Text(label),
      );
    }
    return active
        ? FilledButton.icon(
            onPressed: enabled ? onPressed : null,
            style: FilledButton.styleFrom(
              backgroundColor: SteelColors.primary.withValues(alpha: .12),
              foregroundColor: SteelColors.primary,
            ),
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(onPressed: enabled ? onPressed : null, icon: Icon(icon), label: Text(label));
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withValues(alpha: .22))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 14), const SizedBox(width: 5), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 9.5))]),
      );
}

class _DarkBadge extends StatelessWidget {
  const _DarkBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: .22), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withValues(alpha: .42))),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9)),
      );
}

Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

bool _boolFirst(List<dynamic> values) {
  for (final value in values) {
    if (value is bool) return value;
  }
  return false;
}

bool? _nullableBool(dynamic value) => value is bool ? value : null;

int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;

String _formatDate(dynamic value) {
  final date = DateTime.tryParse('$value');
  if (date == null) return '$value';
  return DateFormat('dd/MM/yyyy HH:mm:ss').format(date.toLocal());
}
