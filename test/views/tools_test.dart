import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1200, 1000);
  });

  tearDown(() => container.dispose());

  testWidgets('shows the outbound interface between settings and other', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(
            interfaceNameMode: InterfaceNameMode.custom,
            interfaceName: 'WLAN',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ToolsView()),
      ),
    );
    await tester.pumpAndSettle();

    final localizations = currentAppLocalizations;
    expect(find.text(localizations.network), findsOneWidget);
    expect(find.text(localizations.interfaceNameMode), findsOneWidget);
    expect(
      find.text('${localizations.interfaceNameModeCustom} · WLAN'),
      findsOneWidget,
    );

    final settingsY = tester.getTopLeft(find.text(localizations.settings)).dy;
    final networkY = tester.getTopLeft(find.text(localizations.network)).dy;
    final otherY = tester.getTopLeft(find.text(localizations.other)).dy;
    expect(settingsY, lessThan(networkY));
    expect(networkY, lessThan(otherY));
  }, skip: !Platform.isWindows);

  testWidgets('opens the dedicated outbound interface page', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(
            interfaceNameMode: InterfaceNameMode.custom,
            interfaceName: 'WLAN',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ToolsView()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(currentAppLocalizations.interfaceNameMode));
    await tester.pumpAndSettle();

    expect(find.byType(InterfaceNameModeItem), findsOneWidget);
    expect(find.byType(InterfaceNameItem), findsOneWidget);
  }, skip: !Platform.isWindows);
}
