import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import '../core/app_strings.dart';
import '../models/machine.dart';
import '../models/session.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/company_service.dart';
import '../services/machine_service.dart';
import '../services/session_store.dart';
import '../services/session_event_service.dart';

class AppController extends ChangeNotifier {
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
      } on ApiException catch (exception) {
        if (exception.statusCode == 401) {
          await logout(forcedMessage: AppStrings(language).get('sessionRevoked'));
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
    await _guard(() async {
      final json = await auth.login(email, password);
      if (json['mfaRequired'] == true) {
        throw ApiException(
          '${json['mensagem'] ?? 'Confirme o código administrativo.'}',
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
    await _guard(() async {
      final json = await auth.faceLogin(
        finalImage: finalImage,
        livenessImage: livenessImage,
      );
      await _acceptSession(json, newAccount: false);
    });
  }

  Future<void> acceptRegisteredSession(Map<String, dynamic> json) async {
    await _acceptSession(json, newAccount: true);
  }

  Future<void> acceptFaceSecondFactorSession(Map<String, dynamic> json) async {
    await _acceptSession(json, newAccount: false);
  }

  Future<void> _acceptSession(Map<String, dynamic> json, {required bool newAccount}) async {
    final parsed = Session.fromJson(json);
    if (parsed.token.isEmpty) throw ApiException(AppStrings(language).get('invalidSession'));
    session = parsed;
    pendingWelcome = WelcomeNotice(name: parsed.user.name, newAccount: newAccount);
    await _sessionStore.save(json);
    _configureServices();
    await loadMachines();
    _startSessionEvents();
  }

  Future<void> loadMachines({bool notify = false}) async {
    final expectedCompanyId = session?.company.id ?? 0;
    machineSyncServer = ApiConfig.baseUrl;

    try {
      final snapshot = await machinesApi.sync();
      machineSyncCompanyId = snapshot.companyId > 0 ? snapshot.companyId : expectedCompanyId;
      machineSyncCount = snapshot.machines.length;
      machineSyncError = null;

      if (snapshot.companyId > 0 &&
          expectedCompanyId > 0 &&
          snapshot.companyId != expectedCompanyId) {
        final message = AppStrings(language).get('serverSessionMismatch');
        machineSyncError = message;
        await logout(forcedMessage: message);
        throw ApiException(message, statusCode: 409);
      }

      machines = snapshot.machines;
      if (selectedMachine != null) {
        final selectedId = selectedMachine!.id;
        Machine? updated;
        for (final machine in machines) {
          if (machine.id == selectedId) {
            updated = machine;
            break;
          }
        }
        selectedMachine = updated;
        if (updated == null) _stopMachineEvents();
      }
      if (notify) notifyListeners();
    } on ApiException catch (exception) {
      machineSyncServer = ApiConfig.baseUrl;
      machineSyncError = exception.message;
      machineSyncCount = null;
      if (notify) notifyListeners();

      if (exception.statusCode == 401 && isAuthenticated) {
        await logout(
          forcedMessage: AppStrings(language).get('sessionRevoked'),
        );
      }
      rethrow;
    }
  }

  Future<void> selectMachine(Machine machine) async {
    // Carrega o snapshot completo antes de trocar a tela. Antes havia duas
    // reconstruções pesadas (card e resposta da API) durante a navegação.
    final selected = await _withLatestDiagnostics(
      await machinesApi.find(machine.id),
    );
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
    selectedMachine = await _withLatestDiagnostics(
      await machinesApi.find(id),
    );
    notifyListeners();
  }

  Future<Machine> _withLatestDiagnostics(Machine machine) async {
    try {
      final diagnostic = await machinesApi.diagnostics(machine.id);
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
    _stopMachineEvents();
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
  }

  void _startSessionEvents() {
    final token = session?.token ?? '';
    if (token.isEmpty) return;

    _sessionEvents?.stop();
    final service = SessionEventService(
      token: token,
      onRevoked: (reason) async {
        if (!isAuthenticated) return;
        await logout(
          forcedMessage: reason.trim().isEmpty
              ? AppStrings(language).get('sessionRevoked')
              : reason,
        );
      },
      onProfile: (userJson) async {
        final current = session;
        if (current == null || !isAuthenticated) return;

        final updatedUser = UserProfile.fromJson(userJson);
        if (updatedUser.id != current.user.id || updatedUser.id <= 0) return;

        final changed = updatedUser.name != current.user.name ||
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
      if (generation != _machineEventGeneration || selectedMachine?.id != machineId) return;
      _machineReconnect?.cancel();
      _machineReconnect = Timer(const Duration(seconds: 2), connect);
    }

    connect = () {
      if (generation != _machineEventGeneration || selectedMachine?.id != machineId || !isAuthenticated) return;
      _machineEvents?.cancel();
      _machineEvents = machinesApi.events(machineId).listen(
        (event) {
          if (generation != _machineEventGeneration || selectedMachine?.id != machineId) return;
          // Eventos de comando não alteram o snapshot da máquina. Ignorá-los
          // aqui evita reconstruir o dashboard inteiro a cada ACK do Edge.
          if ('${event['tipo'] ?? ''}' == 'comando') return;
          final raw = event['dados'];
          if (raw is! Map) return;

          final current = selectedMachine;
          if (current == null || current.id != machineId) return;
          final updated = current.mergeRealtime(Map<String, dynamic>.from(raw));
          selectedMachine = updated;
          machines = machines
              .map((item) => item.id == machineId ? updated : item)
              .toList(growable: false);
          // Telemetria pode chegar dezenas de vezes por segundo. Atualizamos o
          // modelo imediatamente, mas limitamos repaints globais a 4 Hz.
          _machineUiRefresh ??= Timer(const Duration(milliseconds: 250), () {
            _machineUiRefresh = null;
            if (selectedMachine?.id == machineId && isAuthenticated) {
              notifyListeners();
            }
          });
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
    await ApiConfig.save(value);
    _configureServices();
    machineSyncServer = ApiConfig.baseUrl;
    if (isAuthenticated) {
      // Ao trocar de backend, valida imediatamente a sessão/empresa nesse
      // servidor. Isso impede mostrar usuário cacheado com lista vazia.
      await loadMachines();
      _startSessionEvents();
      if (selectedMachine != null) _startMachineEvents();
    }
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
