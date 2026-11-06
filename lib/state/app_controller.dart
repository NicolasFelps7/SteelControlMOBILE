import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import 'machine_sync_scope.dart';
import '../core/app_strings.dart';
import '../models/machine.dart';
import '../models/session.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/company_service.dart';
import '../services/machine_service.dart';
import '../services/session_store.dart';
import '../services/session_event_service.dart';

class AppController extends ChangeNotifier with WidgetsBindingObserver {
  AppController();

  final SessionStore _sessionStore = SessionStore();
  late ApiClient _client;
  late AuthService auth;
  late MachineService machinesApi;
  late CompanyService companyApi;
  SessionEventService? _sessionEvents;
  StreamSubscription<Map<String, dynamic>>? _machineEvents;
  Timer? _machineReconnect;
  Timer? _machineUiRefresh;
  int _machineEventGeneration = 0;

  final MachineSyncScope _syncScope = MachineSyncScope();
  Future<void>? _snapshotLoad;
  bool _reloadSnapshot = false;
  StreamSubscription<Map<String, dynamic>>? _companyEvents;
  Timer? _companyReconnect;
  Timer? _companyDebounce;
  Timer? _companyFallback;
  int _companyGeneration = 0;
  bool _observingLifecycle = false;

  Session? session;
  List<Machine> machines = const [];
  Machine? selectedMachine;
  bool initializing = true;
  bool busy = false;
  bool darkMode = false;
  AppLanguage language = AppLanguage.pt;
  String? error;
  WelcomeNotice? pendingWelcome;
  String? forcedLogoutNotice;
  String machineSyncServer = ApiConfig.baseUrl;
  int? machineSyncCompanyId;
  int? machineSyncCount;
  String? machineSyncError;

  bool get isAuthenticated => session?.token.isNotEmpty == true;

  Future<void> initialize() async {
    if (!_observingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }
    await ApiConfig.load();
    final preferences = await SharedPreferences.getInstance();
    darkMode = preferences.getBool('dark_mode') ?? false;
    final savedLanguage = (preferences.getInt('language') ?? 0)
        .clamp(0, AppLanguage.values.length - 1)
        .toInt();
    language = AppLanguage.values[savedLanguage];

    session = await _sessionStore.read();
    _configureServices();

    if (isAuthenticated) {
      try {
        await loadMachines();
        _startSessionEvents();
        _startCompanyEvents();
      } on ApiException catch (exception) {
        if (exception.statusCode == 401) {
          await logout(
            forcedMessage: AppStrings(language).get('sessionRevoked'),
          );
        } else {
          error = exception.message;
        }
      }
    }

    initializing = false;
    notifyListeners();
  }

  void _configureServices() {
    _client = ApiClient(token: session?.token, language: language);
    auth = AuthService(_client);
    machinesApi = MachineService(_client);
    companyApi = CompanyService(_client);
  }

  Future<void> login(String email, String password) async {
    final scope = _syncScope.generation;
    await _guard(() async {
      final json = await auth.login(email, password);
      if (!_syncScope.accepts(scope)) return;
      if (json['mfaRequired'] == true) {
        throw ApiException(
          '${json['mensagem'] ?? AppStrings(language).get('registrationConfirmation')}',
          statusCode: 202,
          code: '${json['codigo'] ?? 'ADMIN_MFA_REQUIRED'}',
          data: json,
        );
      }
      await _acceptSession(json, newAccount: false);
    });
  }

  Future<void> verifyAdminMfa(String challengeId, String code) async {
    await _guard(() async {
      final json = await auth.verifyAdminMfa(
        challengeId: challengeId,
        code: code,
      );
      await _acceptSession(json, newAccount: false);
    });
  }

  Future<void> loginWithFace(File finalImage, File livenessImage) async {
    final scope = _syncScope.generation;
    await _guard(() async {
      final json = await auth.faceLogin(
        finalImage: finalImage,
        livenessImage: livenessImage,
      );
      if (!_syncScope.accepts(scope)) return;
      if (json['mfaRequired'] == true) {
        throw ApiException(
          '${json['mensagem'] ?? AppStrings(language).get('registrationConfirmation')}',
          statusCode: 202,
          code: 'ADMIN_MFA_REQUIRED',
          data: json,
        );
      }
      await _acceptSession(json, newAccount: false);
    });
  }

  Future<void> acceptRegisteredSession(Map<String, dynamic> json) async {
    await _acceptSession(json, newAccount: true);
  }

  Future<void> acceptFaceSecondFactorSession(Map<String, dynamic> json) async {
    await _acceptSession(json, newAccount: false);
  }

  Future<void> _acceptSession(
    Map<String, dynamic> json, {
    required bool newAccount,
  }) async {
    if (json['pendente'] == true || json['mfaRequired'] == true) {
      throw ApiException(
        '${json['mensagem'] ?? 'Acesso aguardando validação.'}',
      );
    }
    final parsed = Session.fromJson(json);
    if (parsed.token.isEmpty)
      throw ApiException(AppStrings(language).get('invalidSession'));
    _resetMachineScope();
    session = parsed;
    pendingWelcome = WelcomeNotice(
      name: parsed.user.name,
      newAccount: newAccount,
    );
    await _sessionStore.save(json);
    _configureServices();
    await loadMachines();
    _startSessionEvents();
    _startCompanyEvents();
  }

  Future<void> loadMachines({bool notify = false}) async {
    if (!isAuthenticated) return;
    final active = _snapshotLoad;
    if (active != null) {
      _reloadSnapshot = true;
      await active;
      if (notify) notifyListeners();
      return;
    }
    final scope = _syncScope.generation;
    final service = machinesApi;
    final companyId = session!.company.id;
    late Future<void> pending;
    pending = (() async {
      var passes = 0;
      do {
        _reloadSnapshot = false;
        await _loadSnapshot(service, companyId, scope);
        passes++;
      } while (_reloadSnapshot &&
          passes < 2 &&
          _syncScope.accepts(scope) &&
          isAuthenticated);
    })();
    _snapshotLoad = pending;
    try {
      await pending;
      if (notify && _syncScope.accepts(scope)) notifyListeners();
    } finally {
      if (identical(_snapshotLoad, pending)) {
        _snapshotLoad = null;
        if (_reloadSnapshot && _syncScope.accepts(scope) && isAuthenticated) {
          scheduleMicrotask(_refreshCompanySnapshot);
        }
      }
    }
  }

  Future<void> _loadSnapshot(
    MachineService service,
    int companyId,
    int scope,
  ) async {
    try {
      final snapshot = await service.sync();
      if (!_syncScope.accepts(scope) || !isAuthenticated) return;
      machineSyncServer = service.client.baseUrl;
      machineSyncCompanyId = snapshot.companyId > 0
          ? snapshot.companyId
          : companyId;
      machineSyncError = null;
      if (snapshot.companyId > 0 &&
          companyId > 0 &&
          snapshot.companyId != companyId) {
        await logout(
          forcedMessage: AppStrings(language).get('serverSessionMismatch'),
        );
        return;
      }
      final existingIds = snapshot.machines.map((m) => m.id).toSet();
      for (final oldMachine in machines) {
        if (!existingIds.contains(oldMachine.id))
          _syncScope.remove(oldMachine.id);
      }
      machines = snapshot.machines
          .where((m) => !_syncScope.isRemoved(m.id))
          .toList(growable: false);
      machineSyncCount = machines.length;
      if (selectedMachine != null) {
        selectedMachine = machines
            .where((m) => m.id == selectedMachine!.id)
            .firstOrNull;
        if (selectedMachine == null) _stopMachineEvents();
      }
      notifyListeners();
    } on ApiException catch (exception) {
      if (!_syncScope.accepts(scope)) return;
      machineSyncError = exception.message;
      machineSyncCount = null;
      if (exception.statusCode == 401 && isAuthenticated) {
        await logout(forcedMessage: AppStrings(language).get('sessionRevoked'));
      }
      rethrow;
    }
  }

  void removeMachineLocally(int id) {
    _syncScope.remove(id);
    machines = machines.where((m) => m.id != id).toList(growable: false);
    if (selectedMachine?.id == id) {
      _stopMachineEvents();
      selectedMachine = null;
    }
    machineSyncCount = machines.length;
    notifyListeners();
  }

  void _resetMachineScope() {
    _syncScope.reset();
    _snapshotLoad = null;
    _reloadSnapshot = false;
    _stopMachineEvents();
    _stopCompanyEvents();
    machines = const [];
    selectedMachine = null;
    machineSyncCount = null;
    machineSyncCompanyId = null;
    machineSyncError = null;
  }

  void _refreshCompanySnapshot() {
    if (!isAuthenticated) return;
    unawaited(
      loadMachines(notify: true).catchError((Object _) {
        if (isAuthenticated) notifyListeners();
      }),
    );
  }

  void _startCompanyEvents() {
    _stopCompanyEvents();
    if (!isAuthenticated) return;
    final generation = _companyGeneration;
    final service = companyApi;
    late void Function() connect;
    void reconnect() {
      if (generation != _companyGeneration || !isAuthenticated) return;
      _companyReconnect?.cancel();
      _companyReconnect = Timer(const Duration(seconds: 2), connect);
    }

    connect = () {
      if (generation != _companyGeneration || !isAuthenticated) return;
      _companyEvents?.cancel();
      _companyEvents = service.events().listen(
        (event) {
          if (generation != _companyGeneration || !isAuthenticated) return;
          final company = int.tryParse('${event['empresaId'] ?? ''}');
          if (company != null && company != session?.company.id) return;
          final type = '${event['tipo'] ?? ''}';
          final data = event['dados'];
          if (type == 'maquina.desativada' || type == 'maquina.excluida') {
            final id = data is Map
                ? int.tryParse('${data['maquinaId']}')
                : null;
            if (id != null) removeMachineLocally(id);
          }
          if (type == 'conectado' || type.startsWith('maquina.')) {
            // Não reinicia o prazo a cada evento: telemetria contínua não adia o sync.
            _companyDebounce ??= Timer(const Duration(milliseconds: 150), () {
              _companyDebounce = null;
              if (generation == _companyGeneration) _refreshCompanySnapshot();
            });
          }
        },
        onError: (Object error) {
          if (generation != _companyGeneration) return;
          if (error is ApiException && error.statusCode == 401) {
            unawaited(
              logout(forcedMessage: AppStrings(language).get('sessionRevoked')),
            );
          } else {
            reconnect();
          }
        },
        onDone: reconnect,
        cancelOnError: true,
      );
    };
    connect();
    _companyFallback = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshCompanySnapshot(),
    );
  }

  void _stopCompanyEvents() {
    _companyGeneration++;
    _companyEvents?.cancel();
    _companyEvents = null;
    _companyReconnect?.cancel();
    _companyDebounce?.cancel();
    _companyFallback?.cancel();
    _companyDebounce = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isAuthenticated) return;
    if (state == AppLifecycleState.resumed) {
      _refreshCompanySnapshot();
      _startCompanyEvents();
      _startSessionEvents();
      if (selectedMachine != null) _startMachineEvents();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopCompanyEvents();
      _stopMachineEvents();
    }
  }

  Future<void> selectMachine(Machine machine) async {
    // Carrega o snapshot completo antes de trocar a tela. Antes havia duas
    // reconstruções pesadas (card e resposta da API) durante a navegação.
    final scope = _syncScope.generation;
    final service = machinesApi;
    final selected = await _withLatestDiagnostics(
      await service.find(machine.id),
      source: service,
    );
    if (!_syncScope.accepts(scope) ||
        _syncScope.isRemoved(selected.id) ||
        !isAuthenticated)
      return;
    selectedMachine = selected;
    machines = machines
        .map((item) => item.id == selected.id ? selected : item)
        .toList(growable: false);
    _startMachineEvents();
    notifyListeners();
  }

  void clearSelectedMachine() {
    _stopMachineEvents();
    selectedMachine = null;
    notifyListeners();
  }

  void replaceSelectedMachine(Machine machine, {bool notify = true}) {
    if (!isAuthenticated || _syncScope.isRemoved(machine.id)) return;
    final changed = selectedMachine?.id != machine.id;
    selectedMachine = machine;
    machines = machines
        .map((item) => item.id == machine.id ? machine : item)
        .toList(growable: false);
    if (notify) notifyListeners();
    if (changed) _startMachineEvents();
  }

  Future<void> refreshSelectedMachine() async {
    final id = selectedMachine?.id;
    if (id == null) return;
    final scope = _syncScope.generation;
    final service = machinesApi;
    final updated = await _withLatestDiagnostics(
      await service.find(id),
      source: service,
    );
    if (!_syncScope.accepts(scope) ||
        _syncScope.isRemoved(id) ||
        selectedMachine?.id != id)
      return;
    selectedMachine = updated;
    notifyListeners();
  }

  Future<Machine> _withLatestDiagnostics(
    Machine machine, {
    MachineService? source,
  }) async {
    final service = source ?? machinesApi;
    try {
      final diagnostic = await service.diagnostics(machine.id);
      final update = <String, dynamic>{};
      final extras = diagnostic['dadosExtras'];
      final integrationMeta = diagnostic['integracaoMeta'];
      if (extras is Map) {
        update['dadosExtras'] = Map<String, dynamic>.from(extras);
      }
      if (integrationMeta is Map) {
        update['integracaoMeta'] = Map<String, dynamic>.from(integrationMeta);
      }
      if (diagnostic.containsKey('qualidadeSinal')) {
        update['qualidadeSinal'] = diagnostic['qualidadeSinal'];
      }
      if (diagnostic.containsKey('latenciaMs')) {
        update['latenciaMs'] = diagnostic['latenciaMs'];
      }
      return update.isEmpty ? machine : machine.mergeRealtime(update);
    } catch (_) {
      // Mantém o snapshot principal quando o diagnóstico estiver indisponível.
      return machine;
    }
  }

  Future<void> logout({String? forcedMessage}) async {
    final remoteLogout = forcedMessage == null && isAuthenticated ? auth : null;
    // Remove primeiro o acesso local. A revogação remota é tentada sem reter o token.
    _resetMachineScope();
    await _sessionEvents?.stop();
    _sessionEvents = null;
    await _sessionStore.clear();
    session = null;
    machines = const [];
    selectedMachine = null;
    error = null;
    pendingWelcome = null;
    forcedLogoutNotice = forcedMessage;
    _configureServices();
    notifyListeners();
    if (remoteLogout != null) {
      try {
        await remoteLogout.logout();
      } catch (_) {
        forcedLogoutNotice = AppStrings(language).get('logoutRemoteFailed');
        notifyListeners();
      }
    }
  }

  void _startSessionEvents() {
    final token = session?.token ?? '';
    final scope = _syncScope.generation;
    if (token.isEmpty) return;

    _sessionEvents?.stop();
    final service = SessionEventService(
      token: token,
      onRevoked: (reason) async {
        if (!isAuthenticated || !_syncScope.accepts(scope)) return;
        await logout(
          forcedMessage: reason.trim().isEmpty
              ? AppStrings(language).get('sessionRevoked')
              : reason,
        );
      },
      onProfile: (userJson) async {
        final current = session;
        if (current == null || !isAuthenticated || !_syncScope.accepts(scope))
          return;

        final updatedUser = UserProfile.fromJson(userJson);
        if (updatedUser.id != current.user.id || updatedUser.id <= 0) return;

        final changed =
            updatedUser.name != current.user.name ||
            updatedUser.email != current.user.email ||
            updatedUser.role != current.user.role;
        if (!changed) return;

        session = Session(
          token: current.token,
          user: updatedUser,
          company: current.company,
        );
        await _sessionStore.save(session!.toJson());
        _configureServices();
        notifyListeners();
      },
    );
    _sessionEvents = service;
    service.start();
  }

  void _startMachineEvents() {
    final machineId = selectedMachine?.id;
    if (machineId == null || !isAuthenticated) return;

    _stopMachineEvents();
    final generation = ++_machineEventGeneration;

    late void Function() connect;

    void scheduleReconnect() {
      if (generation != _machineEventGeneration ||
          selectedMachine?.id != machineId)
        return;
      _machineReconnect?.cancel();
      _machineReconnect = Timer(const Duration(seconds: 2), connect);
    }

    connect = () {
      if (generation != _machineEventGeneration ||
          selectedMachine?.id != machineId ||
          !isAuthenticated)
        return;
      _machineEvents?.cancel();
      _machineEvents = machinesApi
          .events(machineId)
          .listen(
            (event) {
              if (generation != _machineEventGeneration ||
                  selectedMachine?.id != machineId)
                return;
              // Eventos de comando não alteram o snapshot da máquina. Ignorá-los
              // aqui evita reconstruir o dashboard inteiro a cada ACK do Edge.
              if ('${event['tipo'] ?? ''}' == 'comando') return;
              final raw = event['dados'];
              if (raw is! Map) return;

              final current = selectedMachine;
              if (current == null || current.id != machineId) return;
              final updated = current.mergeRealtime(
                Map<String, dynamic>.from(raw),
              );
              selectedMachine = updated;
              machines = machines
                  .map((item) => item.id == machineId ? updated : item)
                  .toList(growable: false);
              // Telemetria pode chegar dezenas de vezes por segundo. Atualizamos o
              // modelo imediatamente, mas limitamos repaints globais a 4 Hz.
              _machineUiRefresh ??= Timer(
                const Duration(milliseconds: 250),
                () {
                  _machineUiRefresh = null;
                  if (selectedMachine?.id == machineId && isAuthenticated) {
                    notifyListeners();
                  }
                },
              );
            },
            onError: (_) => scheduleReconnect(),
            onDone: scheduleReconnect,
            cancelOnError: true,
          );
    };

    connect();
  }

  void _stopMachineEvents() {
    _machineEventGeneration += 1;
    _machineReconnect?.cancel();
    _machineReconnect = null;
    _machineEvents?.cancel();
    _machineEvents = null;
    _machineUiRefresh?.cancel();
    _machineUiRefresh = null;
  }

  String? consumeForcedLogoutNotice() {
    final value = forcedLogoutNotice;
    forcedLogoutNotice = null;
    return value;
  }

  WelcomeNotice? consumeWelcome() {
    final value = pendingWelcome;
    pendingWelcome = null;
    return value;
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('dark_mode', value);
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage value) async {
    language = value;
    _configureServices();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('language', AppLanguage.values.indexOf(value));
    notifyListeners();
  }

  Future<void> updateApiUrl(String value) async {
    final normalized = ApiConfig.normalize(value);
    if (normalized == ApiConfig.baseUrl) return;
    // Não transfere a sessão de uma empresa para um servidor diferente.
    if (isAuthenticated) {
      await logout();
    } else {
      _resetMachineScope();
    }
    await ApiConfig.save(normalized);
    _configureServices();
    machineSyncServer = ApiConfig.baseUrl;
    notifyListeners();
  }

  Future<void> testApiConnection() async {
    final result = await _client.get('/api/health');
    if (result is! Map || result['status'] != 'ok') {
      throw ApiException(AppStrings(language).get('invalidServerResponse'));
    }
  }

  @override
  void dispose() {
    if (_observingLifecycle) WidgetsBinding.instance.removeObserver(this);
    _stopCompanyEvents();
    _stopMachineEvents();
    _sessionEvents?.stop();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() operation) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await operation();
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

class WelcomeNotice {
  const WelcomeNotice({required this.name, required this.newAccount});

  final String name;
  final bool newAccount;
}
