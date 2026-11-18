import 'dart:convert';

import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('config stores tailscale settings independently of profiles', () {
    final json =
        jsonDecode(jsonEncode(Config.realFromJson(null).toJson()))
            as Map<String, dynamic>;
    final tailscale = json['tailscaleProps'];

    expect(tailscale, isA<Map>());
    expect((tailscale as Map)['enabled'], false);
    expect((tailscale)['routeTailnet'], true);
    expect((tailscale)['udp'], true);
  });

  test('tailscale settings redact the auth key from diagnostics', () {
    const authKey = 'tskey-auth-sensitive-value';
    const props = TailscaleProps(authKey: authKey);

    expect(props.toString(), isNot(contains(authKey)));
    expect(props.toString(), contains('authKey: ***'));
  });
}
