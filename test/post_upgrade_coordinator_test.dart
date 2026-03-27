import 'package:flutter_test/flutter_test.dart';

import 'package:intellicawifi_cross/services/post_upgrade_coordinator.dart';

void main() {
  group('PostUpgradeCoordinator.normalizeVersion', () {
    test('trims and lowercases for safe compare', () {
      expect(PostUpgradeCoordinator.normalizeVersion('  RDKB-1.2.3  '), 'rdkb-1.2.3');
      expect(PostUpgradeCoordinator.normalizeVersion('Version-ABC'), 'version-abc');
      expect(PostUpgradeCoordinator.normalizeVersion(''), '');
    });
  });
}
