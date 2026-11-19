import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/tailscale/tailscale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import '../helpers/network_interfaces.dart';

class _TailscaleCore extends CoreHandlerInterface {
  _TailscaleCore({
    this.backendState = 'NeedsLogin',
    this.authUrl = 'https://login.tailscale.test/abc',
    this.online = false,
  });

  final String backendState;
  final String authUrl;
  final bool online;
  final List<CoreMethod> calls = [];

  @override
  Future<CoreLifecycleResult> start() async => const CoreLifecycleResult(
    revision: 1,
    outcome: CoreLifecycleOutcome.applied,
  );

  @override
  Future<CoreLifecycleResult> restart() => start();

  @override
  Future<CoreLifecycleResult> stop() => start();

  @override
  Future<CoreLifecycleResult> close() => start();

  @override
  Future<Object?> invokeMethod({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    calls.add(method);
    return switch (method) {
      CoreMethod.tailscaleStatus => {
        'backend-state': backendState,
        'auth-url': authUrl,
        'hostname': 'flclash-test',
        'control-url': 'https://controlplane.tailscale.com',
        'interface-name': 'WLAN',
        'magic-dns-suffix': 'tailnet.ts.net',
        'addresses': <String>[],
        'health': <String>[],
        'online': online,
      },
      CoreMethod.tailscaleLogin || CoreMethod.tailscaleLogout => null,
      _ => null,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tailscale page exposes status control and info sections', (
    tester,
  ) async {
    await AppLocalizations.load(const Locale('en'));
    final container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: TailscaleView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Status'), findsAtLeastNWidgets(1));
    expect(find.text('Control'), findsAtLeastNWidgets(1));
    expect(find.text('Info'), findsAtLeastNWidgets(1));
  });

  testWidgets('control tab edits tailscale and its network interface', (
    tester,
  ) async {
    await AppLocalizations.load(const Locale('en'));
    final container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    final lister = listNetworkInterfaces;
    addTearDown(() => listNetworkInterfaces = lister);
    listNetworkInterfaces = ({includeLoopback = false}) async => [
      testNetworkInterface('WLAN', addresses: ['192.168.1.20']),
    ];
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: TailscaleView()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Control').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(container.read(tailscaleSettingProvider).enabled, isTrue);

    await tester.tap(find.text('Interface name'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WLAN (192.168.1.20)'));
    await tester.pumpAndSettle();

    expect(container.read(tailscaleSettingProvider).interfaceName, 'WLAN');
  });

  testWidgets('global mode warns and switches to rule mode', (tester) async {
    await AppLocalizations.load(const Locale('en'));
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        tailscaleSettingProvider.overrideWithBuild(
          (_, _) => const TailscaleProps(enabled: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mode: Mode.global));
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: TailscaleView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rule mode is required'), findsOneWidget);

    await tester.tap(find.text('Rule mode is required'));
    await tester.pumpAndSettle();

    expect(container.read(patchClashConfigProvider).mode, Mode.rule);
  });

  testWidgets('status tab reads and logs in through Core', (tester) async {
    await AppLocalizations.load(const Locale('en'));
    final core = _TailscaleCore();
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        tailscaleSettingProvider.overrideWithBuild(
          (_, _) => const TailscaleProps(enabled: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: TailscaleView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login required'), findsAtLeastNWidgets(1));
    expect(find.text('https://login.tailscale.test/abc'), findsOneWidget);

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(core.calls, contains(CoreMethod.tailscaleLogin));
  });

  testWidgets('online status can log out through Core', (tester) async {
    await AppLocalizations.load(const Locale('en'));
    final core = _TailscaleCore(
      backendState: 'Running',
      authUrl: '',
      online: true,
    );
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        tailscaleSettingProvider.overrideWithBuild(
          (_, _) => const TailscaleProps(enabled: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: TailscaleView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(core.calls, contains(CoreMethod.tailscaleLogout));
  });
}
