import 'dart:developer';

import '../models/models.dart';
import '../repositories/firmware_repository.dart';
import '../repositories/troubleshooting_repository.dart';
import '../utils/fw_upgrade_status_parser.dart';
import '../utils/post_upgrade_state_manager.dart';
import '../utils/sanity_test_parser.dart';

enum PostUpgradeRunStatus {
  noPending,
  promptReady,
  skippedUpgradeFailed,
  running,
  completed,
  alreadyRan,
  versionMismatch,
  failed,
}

class PostUpgradeRunResult {
  final PostUpgradeRunStatus status;
  final String message;

  const PostUpgradeRunResult({
    required this.status,
    required this.message,
  });
}

class PostUpgradeCoordinator {
  final PostUpgradeStateManager _stateManager;
  final FirmwareRepository _firmwareRepository;
  final TroubleshootingRepository _troubleshootingRepository;

  static bool _isRunning = false;

  PostUpgradeCoordinator({
    PostUpgradeStateManager? stateManager,
    FirmwareRepository? firmwareRepository,
    TroubleshootingRepository? troubleshootingRepository,
  })  : _stateManager = stateManager ?? PostUpgradeStateManager(),
        _firmwareRepository = firmwareRepository ?? FirmwareRepository(),
        _troubleshootingRepository =
            troubleshootingRepository ?? TroubleshootingRepository();

  static String normalizeVersion(String value) => value.trim().toLowerCase();

  Future<PostUpgradeRunResult> checkAndRun({
    required String mac,
    required String currentVersion,
  }) async {
    if (_isRunning) {
      return const PostUpgradeRunResult(
        status: PostUpgradeRunStatus.running,
        message: 'Post-upgrade sanity check is already running.',
      );
    }

    _isRunning = true;
    try {
      final pending = await _stateManager.getPendingState(mac);
      if (!pending.isPending) {
        return const PostUpgradeRunResult(
          status: PostUpgradeRunStatus.noPending,
          message: 'No pending post-upgrade verification.',
        );
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final markedAt = pending.markedAtEpoch;
      if (markedAt != null && now - markedAt > const Duration(hours: 24).inMilliseconds) {
        log(
          'Pending post-upgrade state older than 24h for $mac',
          name: 'PostUpgradeCoordinator',
        );
      }

      String remoteVersion = '';
      try {
        final xconf = await _firmwareRepository.getXconfFirmwareInfo();
        remoteVersion = xconf.displayFilename;
      } catch (e) {
        log(
          'Unable to fetch remote version, using stored target: $e',
          name: 'PostUpgradeCoordinator',
        );
      }

      final expectedVersion = normalizeVersion(
        (pending.targetVersion ?? '').isNotEmpty
            ? (pending.targetVersion ?? '')
            : remoteVersion,
      );
      final normalizedCurrent = normalizeVersion(currentVersion);

      if (expectedVersion.isEmpty || expectedVersion != normalizedCurrent) {
        return PostUpgradeRunResult(
          status: PostUpgradeRunStatus.versionMismatch,
          message: 'Pending exists, but current version does not match target.',
        );
      }

      if (normalizeVersion(pending.sanityRanForVersion ?? '') == expectedVersion) {
        await _stateManager.clearPending(mac);
        return const PostUpgradeRunResult(
          status: PostUpgradeRunStatus.alreadyRan,
          message: 'Sanity test was already run for this version.',
        );
      }

      log(
        'Auto-running post-upgrade sanity test for $mac',
        name: 'PostUpgradeCoordinator',
      );
      final raw = await _troubleshootingRepository.runTest('Device.Bananapi.temp1');
      final parsed = parseSanityTestLog(raw);

      await _stateManager.markSanityRunCompleted(
        mac: mac,
        version: expectedVersion,
        summary: <String, dynamic>{
          'total': parsed.total,
          'passed': parsed.totalPassed,
          'failed': parsed.totalFailed,
          'allPassed': parsed.allPassed,
          'ranAtEpoch': DateTime.now().millisecondsSinceEpoch,
        },
      );
      await _stateManager.clearPending(mac);

      return PostUpgradeRunResult(
        status: PostUpgradeRunStatus.completed,
        message:
            'Post-upgrade sanity test completed: ${parsed.totalPassed} passed, ${parsed.totalFailed} failed.',
      );
    } catch (e) {
      log(
        'Post-upgrade sanity run failed: $e',
        name: 'PostUpgradeCoordinator',
      );
      return PostUpgradeRunResult(
        status: PostUpgradeRunStatus.failed,
        message: 'Post-upgrade sanity run failed: $e',
      );
    } finally {
      _isRunning = false;
    }
  }

  Future<PostUpgradeRunResult> checkEligibility({
    required String mac,
    required String currentVersion,
  }) async {
    try {
      final pending = await _stateManager.getPendingState(mac);
      if (!pending.isPending) {
        return const PostUpgradeRunResult(
          status: PostUpgradeRunStatus.noPending,
          message: 'No pending post-upgrade verification.',
        );
      }

      String remoteVersion = '';
      try {
        final xconf = await _firmwareRepository.getXconfFirmwareInfo();
        remoteVersion = xconf.displayFilename;
      } catch (e) {
        log(
          'Unable to fetch remote version for eligibility, using stored target: $e',
          name: 'PostUpgradeCoordinator',
        );
      }

      final expectedVersion = normalizeVersion(
        (pending.targetVersion ?? '').isNotEmpty
            ? (pending.targetVersion ?? '')
            : remoteVersion,
      );
      final normalizedCurrent = normalizeVersion(currentVersion);

      if (expectedVersion.isEmpty || expectedVersion != normalizedCurrent) {
        try {
          final fwStatus = await _firmwareRepository.fetchFirmwareUpgradeStatus();
          final parsed = fwStatus.parsedStatus;
          if (parsed.state == FirmwareUpgradeState.failed) {
            await _stateManager.clearPending(mac);
            return const PostUpgradeRunResult(
              status: PostUpgradeRunStatus.skippedUpgradeFailed,
              message: 'Previous firmware upgrade failed. Post-upgrade sanity check was skipped.',
            );
          }
        } catch (_) {
          // If status fetch fails, keep pending and report mismatch so we can retry later.
        }
        return const PostUpgradeRunResult(
          status: PostUpgradeRunStatus.versionMismatch,
          message: 'Pending exists, but current version does not match target.',
        );
      }

      if (normalizeVersion(pending.sanityRanForVersion ?? '') == expectedVersion) {
        await _stateManager.clearPending(mac);
        return const PostUpgradeRunResult(
          status: PostUpgradeRunStatus.alreadyRan,
          message: 'Sanity test was already run for this version.',
        );
      }

      return const PostUpgradeRunResult(
        status: PostUpgradeRunStatus.promptReady,
        message: 'Firmware upgraded successfully. Run post-upgrade sanity test?',
      );
    } catch (e) {
      return PostUpgradeRunResult(
        status: PostUpgradeRunStatus.failed,
        message: 'Failed to evaluate post-upgrade state: $e',
      );
    }
  }
}
