import 'dart:io';

class TestInterfaceAddress implements InterfaceAddress {
  TestInterfaceAddress(this.address, this.type);

  @override
  final String address;

  @override
  final InternetAddressType type;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestNetworkInterface implements NetworkInterface {
  TestNetworkInterface(this.name, this.addresses);

  @override
  final String name;

  @override
  final List<InterfaceAddress> addresses;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NetworkInterface testNetworkInterface(
  String name, {
  List<String> addresses = const [],
}) {
  return TestNetworkInterface(name, [
    for (final address in addresses)
      TestInterfaceAddress(
        address,
        InternetAddress.tryParse(address)?.type ?? InternetAddressType.IPv4,
      ),
  ]);
}
