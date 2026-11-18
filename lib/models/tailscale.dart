class TailscaleStatus {
  final String backendState;
  final String authUrl;
  final String hostname;
  final String controlUrl;
  final String interfaceName;
  final String magicDnsSuffix;
  final List<String> addresses;
  final List<String> health;
  final bool online;

  const TailscaleStatus({
    this.backendState = '',
    this.authUrl = '',
    this.hostname = '',
    this.controlUrl = '',
    this.interfaceName = '',
    this.magicDnsSuffix = '',
    this.addresses = const [],
    this.health = const [],
    this.online = false,
  });

  bool get needsLogin => backendState == 'NeedsLogin';

  factory TailscaleStatus.fromJson(Map<String, Object?> json) {
    return TailscaleStatus(
      backendState: json['backend-state'] as String? ?? '',
      authUrl: json['auth-url'] as String? ?? '',
      hostname: json['hostname'] as String? ?? '',
      controlUrl: json['control-url'] as String? ?? '',
      interfaceName: json['interface-name'] as String? ?? '',
      magicDnsSuffix: json['magic-dns-suffix'] as String? ?? '',
      addresses: [
        for (final address in json['addresses'] as List? ?? const [])
          address.toString(),
      ],
      health: [
        for (final item in json['health'] as List? ?? const []) item.toString(),
      ],
      online: json['online'] as bool? ?? false,
    );
  }
}
