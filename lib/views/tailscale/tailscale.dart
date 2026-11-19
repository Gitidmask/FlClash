import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _TailscaleSection { status, control, info }

class TailscaleView extends ConsumerStatefulWidget {
  const TailscaleView({super.key});

  @override
  ConsumerState<TailscaleView> createState() => _TailscaleViewState();
}

class _TailscaleViewState extends ConsumerState<TailscaleView>
    with WidgetsBindingObserver, ActivePollingMixin<TailscaleView> {
  var _section = _TailscaleSection.status;
  TailscaleStatus? _status;
  String? _statusError;
  var _statusLoading = false;

  CoreController get _core => ref.read(coreHandlerProvider);

  @override
  Duration get pollInterval => const Duration(seconds: 5);

  @override
  Future<void> poll(bool Function() isCurrent) async {
    final enabled = ref.read(tailscaleSettingProvider).enabled;
    final connected = ref.read(coreStatusProvider) == CoreStatus.connected;
    if (!enabled || !connected) {
      if (!isCurrent() ||
          (_status == null && _statusError == null && !_statusLoading)) {
        return;
      }
      setState(() {
        _status = null;
        _statusError = null;
        _statusLoading = false;
      });
      return;
    }
    if (_status == null && !_statusLoading) {
      setState(() => _statusLoading = true);
    }
    try {
      final status = await _core.getTailscaleStatus(tailscaleProxyName);
      if (!isCurrent()) {
        return;
      }
      setState(() {
        _status = status;
        _statusError = null;
        _statusLoading = false;
      });
    } catch (error) {
      if (!isCurrent()) {
        return;
      }
      commonPrint.log(
        'tailscale status error: $error',
        logLevel: coreFailureLogLevel(error),
      );
      setState(() {
        _status = null;
        _statusError = error.toString();
        _statusLoading = false;
      });
    }
  }

  void _selectSection(_TailscaleSection section) {
    if (_section == section) {
      return;
    }
    setState(() => _section = section);
    if (section == _TailscaleSection.status) {
      startPolling();
    } else {
      stopPolling();
    }
  }

  Future<void> _login() async {
    try {
      await _core.loginTailscale(tailscaleProxyName);
      restartPolling();
    } catch (error) {
      dialogs.showBanner(error.toString(), level: BannerLevel.error);
    }
  }

  Future<void> _logout() async {
    try {
      await _core.logoutTailscale(tailscaleProxyName);
      restartPolling();
    } catch (error) {
      dialogs.showBanner(error.toString(), level: BannerLevel.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return BaseScaffold(
      title: appLocalizations.tailscale,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
          top: context.sectionsTopPadding,
          bottom: 16 + context.bottomInset,
        ),
        children: [
          SegmentedControl<_TailscaleSection>(
            segments: [
              (_TailscaleSection.status, appLocalizations.tailscaleStatus),
              (_TailscaleSection.control, appLocalizations.tailscaleControl),
              (_TailscaleSection.info, appLocalizations.tailscaleInfo),
            ],
            value: _section,
            onChanged: _selectSection,
          ),
          switch (_section) {
            _TailscaleSection.status => _TailscaleStatusSection(
              status: _status,
              error: _statusError,
              loading: _statusLoading,
              onLogin: _login,
              onLogout: _logout,
            ),
            _TailscaleSection.control => const _TailscaleControlSection(),
            _TailscaleSection.info => const _TailscaleInfoSection(),
          },
        ],
      ),
    );
  }
}

class _TailscaleStatusSection extends ConsumerWidget {
  final TailscaleStatus? status;
  final String? error;
  final bool loading;
  final Future<void> Function() onLogin;
  final Future<void> Function() onLogout;

  const _TailscaleStatusSection({
    required this.status,
    required this.error,
    required this.loading,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final props = ref.watch(tailscaleSettingProvider);
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final globalInterfaceName = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.interfaceNameMode == InterfaceNameMode.custom
            ? state.interfaceName.trim()
            : '',
      ),
    );
    final connected = ref.watch(coreStatusProvider) == CoreStatus.connected;
    final hostname = props.hostname.trim();
    final interfaceName = props.interfaceName.trim();
    final runtime = status;
    final shownHostname = runtime?.hostname.trim().isNotEmpty == true
        ? runtime!.hostname
        : hostname;
    final shownInterfaceName = runtime?.interfaceName.trim().isNotEmpty == true
        ? runtime!.interfaceName
        : interfaceName.isNotEmpty
        ? interfaceName
        : globalInterfaceName;
    return generateSection(
      title: appLocalizations.tailscaleStatus,
      items: [
        ListItem(
          leading: const GlyphIcon(AppGlyphs.verified),
          title: Text(appLocalizations.enabled),
          trailing: Text(
            props.enabled ? appLocalizations.yes : appLocalizations.no,
          ),
        ),
        if (props.enabled) ...[
          if (props.routeTailnet && mode != Mode.rule)
            ListItem(
              leading: const GlyphIcon(AppGlyphs.warning),
              title: Text(appLocalizations.tailscaleRuleModeRequired),
              subtitle: Text(appLocalizations.tailscaleRuleModeDescription),
              trailing: Text(appLocalizations.rule),
              onTap: () =>
                  ref.read(setupActionProvider.notifier).changeMode(Mode.rule),
            ),
          if (!connected)
            ListItem(
              leading: const GlyphIcon(AppGlyphs.info),
              title: Text(appLocalizations.tailscaleWaitingForCore),
            )
          else if (loading && runtime == null)
            ListItem(
              leading: const GlyphIcon(AppGlyphs.clock),
              title: Text(appLocalizations.loading),
            )
          else if (error != null)
            ListItem(
              leading: const GlyphIcon(AppGlyphs.error),
              title: Text(appLocalizations.error),
              subtitle: Text(error!),
            )
          else if (runtime != null) ...[
            if (runtime.backendState.isNotEmpty)
              ListItem(
                leading: const GlyphIcon(AppGlyphs.status),
                title: Text(appLocalizations.tailscaleBackendState),
                trailing: Text(
                  _tailscaleStateLabel(appLocalizations, runtime.backendState),
                ),
              ),
            if (runtime.addresses.isNotEmpty)
              ListItem(
                leading: const GlyphIcon(AppGlyphs.devices),
                title: Text(appLocalizations.tailscaleNodeAddress),
                subtitle: Text(runtime.addresses.join(', ')),
              ),
            if (runtime.health.isNotEmpty)
              ListItem(
                leading: const GlyphIcon(AppGlyphs.warning),
                title: Text(appLocalizations.tailscaleHealth),
                subtitle: Text(runtime.health.join('\n')),
              ),
            if (runtime.health.isEmpty)
              ListItem(
                leading: const GlyphIcon(AppGlyphs.verified),
                title: Text(appLocalizations.tailscaleHealth),
                trailing: Text(appLocalizations.tailscaleNoHealthIssues),
              ),
            if (runtime.authUrl.isNotEmpty)
              ListItem(
                leading: const GlyphIcon(AppGlyphs.link),
                title: Text(appLocalizations.tailscaleLoginUrl),
                subtitle: Text(runtime.authUrl),
                trailing: const GlyphIcon(AppGlyphs.openExternal),
                onTap: () => dialogs.openUrl(runtime.authUrl),
              ),
            if (runtime.needsLogin)
              ListItem(
                leading: const GlyphIcon(AppGlyphs.account),
                title: Text(appLocalizations.tailscaleLogin),
                trailing: const GlyphIcon(AppGlyphs.chevronForward),
                onTap: () => unawaited(onLogin()),
              ),
            if (runtime.online)
              ListItem(
                leading: const GlyphIcon(AppGlyphs.lockOpen),
                title: Text(appLocalizations.tailscaleLogout),
                trailing: const GlyphIcon(AppGlyphs.chevronForward),
                onTap: () => unawaited(onLogout()),
              ),
          ],
          ListItem(
            leading: const GlyphIcon(AppGlyphs.devices),
            title: Text(appLocalizations.hostname),
            trailing: Text(
              shownHostname.isEmpty
                  ? appLocalizations.defaultText
                  : shownHostname,
            ),
          ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.wifi),
            title: Text(appLocalizations.interfaceName),
            trailing: Text(
              shownInterfaceName.isEmpty
                  ? appLocalizations.tailscaleFollowGlobalInterface
                  : shownInterfaceName,
            ),
          ),
          if (runtime != null && runtime.controlUrl.isNotEmpty)
            ListItem(
              leading: const GlyphIcon(AppGlyphs.link),
              title: Text(appLocalizations.tailscaleControlServer),
              subtitle: Text(runtime.controlUrl),
            ),
          if (runtime != null && runtime.magicDnsSuffix.isNotEmpty)
            ListItem(
              leading: const GlyphIcon(AppGlyphs.dns),
              title: Text(appLocalizations.tailscaleMagicDns),
              subtitle: Text(runtime.magicDnsSuffix),
            ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.shuffle),
            title: Text(appLocalizations.tailscaleRouteTailnet),
            trailing: Text(
              props.routeTailnet ? appLocalizations.yes : appLocalizations.no,
            ),
          ),
        ],
      ],
      footer: appLocalizations.tailscaleNetworkDescription,
    );
  }
}

class _TailscaleControlSection extends StatelessWidget {
  const _TailscaleControlSection();

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Column(
      children: [
        generateSection(
          title: appLocalizations.general,
          items: [
            ConfigToggleItem(
              selector: tailscaleSettingProvider.select(
                (state) => state.enabled,
              ),
              title: (localizations) => localizations.enabled,
              leading: const GlyphIcon(AppGlyphs.verified),
              onChanged: (ref, value) =>
                  _update(ref, (state) => state.copyWith(enabled: value)),
            ),
            ConfigTextItem(
              selector: tailscaleSettingProvider.select(
                (state) => state.hostname,
              ),
              title: (localizations) => localizations.hostname,
              leading: const GlyphIcon(AppGlyphs.devices),
              allowEmpty: true,
              maxLength: TextInputLimits.domain,
              onChanged: (ref, value) => _update(
                ref,
                (state) => state.copyWith(hostname: value.trim()),
              ),
            ),
            const _TailscaleAuthKeyItem(),
          ],
        ),
        generateSection(
          title: appLocalizations.network,
          items: [
            const _TailscaleInterfaceItem(),
            ConfigToggleItem(
              selector: tailscaleSettingProvider.select(
                (state) => state.routeTailnet,
              ),
              title: (localizations) => localizations.tailscaleRouteTailnet,
              leading: const GlyphIcon(AppGlyphs.shuffle),
              onChanged: (ref, value) =>
                  _update(ref, (state) => state.copyWith(routeTailnet: value)),
            ),
            ConfigToggleItem(
              selector: tailscaleSettingProvider.select((state) => state.udp),
              title: (localizations) => localizations.tailscaleUdp,
              leading: const GlyphIcon(AppGlyphs.connections),
              onChanged: (ref, value) =>
                  _update(ref, (state) => state.copyWith(udp: value)),
            ),
            ConfigToggleItem(
              selector: tailscaleSettingProvider.select(
                (state) => state.acceptRoutes,
              ),
              title: (localizations) => localizations.tailscaleAcceptRoutes,
              leading: const GlyphIcon(AppGlyphs.rules),
              onChanged: (ref, value) =>
                  _update(ref, (state) => state.copyWith(acceptRoutes: value)),
            ),
            ConfigTextItem(
              selector: tailscaleSettingProvider.select(
                (state) => state.exitNode,
              ),
              title: (localizations) => localizations.tailscaleExitNode,
              leading: const GlyphIcon(AppGlyphs.openExternal),
              allowEmpty: true,
              maxLength: TextInputLimits.cidr,
              onChanged: (ref, value) => _update(
                ref,
                (state) => state.copyWith(exitNode: value.trim()),
              ),
            ),
            ConfigToggleItem(
              selector: tailscaleSettingProvider.select(
                (state) => state.exitNodeAllowLanAccess,
              ),
              title: (localizations) => localizations.tailscaleExitNodeAllowLan,
              leading: const GlyphIcon(AppGlyphs.devices),
              onChanged: (ref, value) => _update(
                ref,
                (state) => state.copyWith(exitNodeAllowLanAccess: value),
              ),
            ),
          ],
          footer: appLocalizations.tailscaleNetworkDescription,
        ),
        generateSection(
          title: appLocalizations.account,
          items: [
            ConfigTextItem(
              selector: tailscaleSettingProvider.select(
                (state) => state.controlUrl,
              ),
              title: (localizations) => localizations.tailscaleControlServer,
              leading: const GlyphIcon(AppGlyphs.link),
              allowEmpty: true,
              keyboardType: TextInputType.url,
              maxLength: TextInputLimits.uri,
              onChanged: (ref, value) => _update(
                ref,
                (state) => state.copyWith(controlUrl: value.trim()),
              ),
            ),
            ConfigTextItem(
              selector: tailscaleSettingProvider.select(
                (state) => state.stateDir,
              ),
              title: (localizations) => localizations.tailscaleStateDirectory,
              leading: const GlyphIcon(AppGlyphs.profiles),
              maxLength: TextInputLimits.url,
              onChanged: (ref, value) => _update(
                ref,
                (state) => state.copyWith(stateDir: value.trim()),
              ),
            ),
            ConfigToggleItem(
              selector: tailscaleSettingProvider.select(
                (state) => state.ephemeral,
              ),
              title: (localizations) => localizations.tailscaleEphemeral,
              leading: const GlyphIcon(AppGlyphs.clock),
              onChanged: (ref, value) =>
                  _update(ref, (state) => state.copyWith(ephemeral: value)),
            ),
          ],
        ),
        generateSection(
          title: appLocalizations.outbound,
          items: [
            ConfigTextItem(
              selector: tailscaleSettingProvider.select(
                (state) => state.dialerProxy,
              ),
              title: (localizations) => localizations.dialerProxy,
              leading: const GlyphIcon(AppGlyphs.proxies),
              allowEmpty: true,
              maxLength: TextInputLimits.name,
              onChanged: (ref, value) => _update(
                ref,
                (state) => state.copyWith(dialerProxy: value.trim()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TailscaleInfoSection extends StatelessWidget {
  const _TailscaleInfoSection();

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return generateSection(
      title: appLocalizations.tailscaleInfo,
      items: [
        ListItem(
          leading: const GlyphIcon(AppGlyphs.tailscale),
          title: Text(appLocalizations.tailscale),
          subtitle: Text(appLocalizations.tailscaleUserspaceDescription),
        ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.wifi),
          title: Text(appLocalizations.network),
          subtitle: Text(appLocalizations.tailscaleNetworkDescription),
        ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.rules),
          title: Text(appLocalizations.outbound),
          subtitle: Text(appLocalizations.tailscaleRoutingDescription),
        ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.warning),
          title: Text(appLocalizations.disclaimer),
          subtitle: Text(appLocalizations.tailscaleLimitationsDescription),
        ),
      ],
    );
  }
}

class _TailscaleAuthKeyItem extends ConsumerWidget {
  const _TailscaleAuthKeyItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(
      tailscaleSettingProvider.select((state) => state.authKey),
    );
    return ListItem(
      leading: const GlyphIcon(AppGlyphs.key),
      title: Text(appLocalizations.tailscaleAuthKey),
      subtitle: Text(value.isEmpty ? appLocalizations.none : '********'),
      trailing: const GlyphIcon(AppGlyphs.edit),
      onTap: () => _edit(context, ref, value),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, String value) async {
    final appLocalizations = context.appLocalizations;
    final result = await dialogs.showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.tailscaleAuthKey,
        value: value,
        obscureText: true,
        inputFormatters: [
          FilteringTextInputFormatter.singleLineFormatter,
          ...TextInputLimits.limit(TextInputLimits.password),
        ],
      ),
    );
    if (result == null) {
      return;
    }
    _update(ref, (state) => state.copyWith(authKey: result.trim()));
  }
}

class _TailscaleInterfaceItem extends ConsumerWidget {
  const _TailscaleInterfaceItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final interfaceName = ref.watch(
      tailscaleSettingProvider.select((state) => state.interfaceName),
    );
    return ListItem(
      leading: const GlyphIcon(AppGlyphs.wifi),
      title: Text(appLocalizations.interfaceName),
      subtitle: Text(
        interfaceName.isEmpty
            ? appLocalizations.tailscaleFollowGlobalInterface
            : interfaceName,
      ),
      trailing: const GlyphIcon(AppGlyphs.chevronForward),
      onTap: () => _select(context, ref, interfaceName),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    String selected,
  ) async {
    final appLocalizations = context.appLocalizations;
    final interfaces = await getNetworkInterfaces();
    if (!context.mounted) {
      return;
    }
    final byName = {
      for (final interface in interfaces) interface.name: interface,
    };
    String labelOf(String name) {
      if (name.isEmpty) {
        return appLocalizations.tailscaleFollowGlobalInterface;
      }
      final interface = byName[name];
      return interface == null ? name : networkInterfaceLabel(interface);
    }

    final result = await showSheet<String>(
      context: context,
      builder: (_) => SelectionSheet<String>(
        title: appLocalizations.interfaceName,
        sections: [
          SelectionSection(items: ['', ...byName.keys]),
        ],
        labelBuilder: labelOf,
        selectedOf: (_) => selected,
        onSelected: (item) => Navigator.of(context).pop(item),
      ),
    );
    if (result == null) {
      return;
    }
    _update(ref, (state) => state.copyWith(interfaceName: result));
  }
}

void _update(
  WidgetRef ref,
  TailscaleProps Function(TailscaleProps state) update,
) {
  ref.read(tailscaleSettingProvider.notifier).update(update);
}

String _tailscaleStateLabel(AppLocalizations localizations, String state) {
  return switch (state) {
    'Running' => localizations.connected,
    'NeedsLogin' || 'NeedsMachineAuth' => localizations.tailscaleLoginRequired,
    'Starting' => localizations.loading,
    'Stopped' || 'NoState' => localizations.disconnected,
    _ => state,
  };
}
