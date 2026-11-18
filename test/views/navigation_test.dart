import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/views/navigation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tailscale is a desktop destination after profiles', () {
    final items = navigation.getItems(openLogs: true, hasProxies: true);
    final labels = items.map((item) => item.label.name).toList();

    expect(labels, contains('tailscale'));
    final tailscaleIndex = labels.indexOf('tailscale');
    final tailscale = items[tailscaleIndex];
    expect(tailscaleIndex, labels.indexOf('profiles') + 1);
    expect(tailscale.modes, contains(NavigationItemMode.desktop));
    expect(tailscale.modes, isNot(contains(NavigationItemMode.mobile)));
  });

  testWidgets('no navigation view carries a global key of its own', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (value) {
          context = value;
          return const SizedBox();
        },
      ),
    );

    final items = navigation.getItems(openLogs: true, hasProxies: true);

    for (final item in items) {
      expect(item.builder(context).key, isNot(isA<GlobalKey>()));
    }
  });
}
