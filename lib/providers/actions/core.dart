part of '../action.dart';

Future<String?> _windowsInterfaceError(
  PatchClashConfig config,
  TailscaleProps tailscale,
) async {
  if (!system.isWindows) {
    return null;
  }
  final interfaceNames = <String>{};
  if (config.interfaceNameMode == InterfaceNameMode.custom) {
    final interfaceName = config.interfaceName.trim();
    if (interfaceName.isEmpty) {
      return currentAppLocalizations.networkInterfaceNotSelected;
    }
    interfaceNames.add(interfaceName);
  }
  if (tailscale.enabled) {
    final interfaceName = tailscale.interfaceName.trim();
    if (interfaceName.isNotEmpty) {
      interfaceNames.add(interfaceName);
    }
  }
  if (interfaceNames.isEmpty) {
    return null;
  }

  final interfaces = await getNetworkInterfaces();
  final available = {for (final interface in interfaces) interface.name};
  for (final interfaceName in interfaceNames) {
    if (!available.contains(interfaceName)) {
      return currentAppLocalizations.networkInterfaceUnavailable(interfaceName);
    }
  }
  return null;
}

@Riverpod(keepAlive: true)
class CoreAction extends _$CoreAction {
  CoreController get _core => ref.read(coreHandlerProvider);

  int _requestedRestartRevision = 0;
  Future<bool>? _restartOperation;

  @override
  void build() {}

  Future<void> initCore() async {
    final isInit = await _core.isInit;

    final version = ref.read(versionProvider);
    if (!isInit) {
      await _core.init(version);
    } else {
      await ref.read(proxiesActionProvider.notifier).updateGroups();
      await ref.read(providersProvider.notifier).syncProviders();
    }
  }

  Future<void> startCore() async {
    ref.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
    try {
      final interfaceError = await windowsInterfaceError();
      if (interfaceError != null) {
        ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
        dialogs.showBanner(interfaceError, level: BannerLevel.error);
        return;
      }
      final result = await startLifecycle();
      await _applyLifecycleResult(result);
    } catch (error) {
      ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
      dialogs.showBanner(error.toString(), level: BannerLevel.error);
    }
  }

  @protected
  Future<CoreLifecycleResult> startLifecycle() {
    return _core.start();
  }

  @protected
  Future<CoreLifecycleResult> restartLifecycle() {
    return _core.restart();
  }

  // Nothing in lib/ calls CoreController.stop(); only close() (app exit)
  // supersedes a start/restart. statusFirst lets onCrash catch a crash
  // during initCore itself (it early-returns unless status is connected).
  Future<bool> _applyLifecycleResult(
    CoreLifecycleResult result, {
    bool statusFirst = false,
  }) async {
    if (result.outcome == CoreLifecycleOutcome.superseded) {
      return false;
    }
    if (statusFirst) {
      ref.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      await initCore();
    } else {
      await initCore();
      ref.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    }
    if (mitmFeature && ref.read(patchClashConfigProvider).mitm.enable) {
      unawaited(ref.read(mitmTrustStateProvider.notifier).refresh());
    }
    return true;
  }

  Future<void> closeConnection(String id) async {
    await _core.closeConnection(id);
  }

  Future<void> closeConnections() async {
    await _core.closeConnections();
  }

  Future<void> reportNetworkChange() async {
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    try {
      await _core.reportNetworkChange();
    } catch (error) {
      commonPrint.log(
        'reportNetworkChange error: $error',
        logLevel: coreFailureLogLevel(error),
      );
    }
  }

  Future<void> forceGc() async {
    await _core.forceGc();
  }

  Future<void> crash() async {
    await _core.crash();
  }

  Future<bool> restartCore() {
    _requestedRestartRevision++;
    final activeOperation = _restartOperation;
    if (activeOperation != null) {
      return activeOperation;
    }

    final operation = _runRestartWorker();
    _restartOperation = operation;
    return operation;
  }

  @protected
  Future<String?> windowsInterfaceError() {
    return _windowsInterfaceError(
      ref.read(patchClashConfigProvider),
      ref.read(tailscaleSettingProvider),
    );
  }

  Future<bool> _runRestartWorker() async {
    try {
      final interfaceError = await windowsInterfaceError();
      if (interfaceError != null) {
        dialogs.showBanner(interfaceError, level: BannerLevel.error);
        return false;
      }
      ref.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
      final result = await restartLifecycle();
      if (!await _applyLifecycleResult(result, statusFirst: true)) {
        return false;
      }

      var appliedRevision = 0;
      var applied = true;
      while (appliedRevision < _requestedRestartRevision) {
        final revision = _requestedRestartRevision;
        if (ref.read(isStartProvider)) {
          applied = await ref
              .read(setupActionProvider.notifier)
              .setRunning(true, initialize: true);
        } else {
          applied = await ref
              .read(setupActionProvider.notifier)
              .applyProfile(force: true);
        }
        appliedRevision = revision;
      }
      return applied;
    } catch (_) {
      ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
      rethrow;
    } finally {
      _restartOperation = null;
    }
  }
}
