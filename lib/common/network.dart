import 'dart:io';

import 'package:flutter/foundation.dart';

typedef NetworkInterfaceLister =
    Future<List<NetworkInterface>> Function({bool includeLoopback});

@visibleForTesting
NetworkInterfaceLister listNetworkInterfaces =
    ({bool includeLoopback = false}) =>
        NetworkInterface.list(includeLoopback: includeLoopback);

Future<List<NetworkInterface>> getNetworkInterfaces() async {
  final interfaces = await listNetworkInterfaces(includeLoopback: false);
  return interfaces.where((interface) {
      return interface.name.trim().isNotEmpty &&
          interface.addresses.any(_isUsableAddress);
    }).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

bool _isUsableAddress(InterfaceAddress address) {
  final value = address.address.toLowerCase();
  final ip = InternetAddress.tryParse(value);
  return ip != null &&
      !ip.isLoopback &&
      !value.startsWith('169.254.') &&
      !value.startsWith('fe80:') &&
      value != '0.0.0.0' &&
      value != '::';
}

String networkInterfaceLabel(NetworkInterface interface) {
  for (final address in interface.addresses) {
    if (_isUsableAddress(address) && address.type == InternetAddressType.IPv4) {
      return '${interface.name} (${address.address})';
    }
  }
  for (final address in interface.addresses) {
    if (_isUsableAddress(address)) {
      return '${interface.name} (${address.address})';
    }
  }
  return interface.name;
}

extension NetworkInterfaceExt on NetworkInterface {
  bool get isWifi {
    final nameLowCase = name.toLowerCase();
    if (nameLowCase.contains('wlan') ||
        nameLowCase.contains('wi-fi') ||
        nameLowCase == 'en0' ||
        nameLowCase == 'eth0') {
      return true;
    }

    return false;
  }

  bool get includesIPv4 {
    return addresses.any((addr) => addr.isIPv4);
  }
}

extension InternetAddressExt on InternetAddress {
  bool get isIPv4 {
    return type == InternetAddressType.IPv4;
  }
}

Future<String?> getLocalIpAddress() async {
  final List<NetworkInterface> interfaces =
      await listNetworkInterfaces(includeLoopback: false)
        ..sort((a, b) {
          if (a.isWifi && !b.isWifi) return -1;
          if (!a.isWifi && b.isWifi) return 1;
          if (a.includesIPv4 && !b.includesIPv4) return -1;
          if (!a.includesIPv4 && b.includesIPv4) return 1;
          return 0;
        });
  for (final interface in interfaces) {
    final addresses = interface.addresses;
    if (addresses.isEmpty) {
      continue;
    }
    addresses.sort((a, b) {
      if (a.isIPv4 && !b.isIPv4) return -1;
      if (!a.isIPv4 && b.isIPv4) return 1;
      return 0;
    });
    return addresses.first.address;
  }
  return '';
}
