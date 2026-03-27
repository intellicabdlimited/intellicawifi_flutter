import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:intellicawifi_cross/utils/post_upgrade_state_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PostUpgradeStateManager', () {
    late PostUpgradeStateManager manager;
    const macA = 'mac:AA11BB22CC33';
    const macB = 'mac:DD44EE55FF66';

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      manager = PostUpgradeStateManager();
    });

    test('marks ready-to-reboot pending state', () async {
      await manager.markReadyToReboot(mac: macA, targetVersion: '1.2.3');
      final state = await manager.getPendingState(macA);
      expect(state.isPending, isTrue);
      expect(state.targetVersion, '1.2.3');
      expect(state.markedAtEpoch, isNotNull);
    });

    test('stores data namespaced by MAC', () async {
      await manager.markReadyToReboot(mac: macA, targetVersion: '1.2.3');
      await manager.markReadyToReboot(mac: macB, targetVersion: '9.9.9');

      final stateA = await manager.getPendingState(macA);
      final stateB = await manager.getPendingState(macB);

      expect(stateA.targetVersion, '1.2.3');
      expect(stateB.targetVersion, '9.9.9');
    });

    test('clearPending keeps run-history but clears pending fields', () async {
      await manager.markReadyToReboot(mac: macA, targetVersion: '1.2.3');
      await manager.markSanityRunCompleted(
        mac: macA,
        version: '1.2.3',
        summary: <String, dynamic>{'passed': 3, 'failed': 0},
      );
      await manager.clearPending(macA);

      final state = await manager.getPendingState(macA);
      expect(state.isPending, isFalse);
      expect(state.targetVersion, isNull);
      expect(state.markedAtEpoch, isNull);
      expect(state.sanityRanForVersion, '1.2.3');
      expect(state.lastResultSummary, isNotNull);
    });
  });
}
