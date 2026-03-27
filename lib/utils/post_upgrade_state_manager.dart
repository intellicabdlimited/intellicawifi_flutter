import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PostUpgradePendingState {
  final bool isPending;
  final String? targetVersion;
  final int? markedAtEpoch;
  final String? sanityRanForVersion;
  final String? lastResultSummary;

  const PostUpgradePendingState({
    required this.isPending,
    this.targetVersion,
    this.markedAtEpoch,
    this.sanityRanForVersion,
    this.lastResultSummary,
  });
}

class PostUpgradeStateManager {
  static const String _kPending = 'fw_is_upgraded_pending';
  static const String _kTargetVersion = 'fw_target_version';
  static const String _kMarkedAtEpoch = 'fw_marked_at_epoch';
  static const String _kSanityRanForVersion = 'fw_sanity_ran_for_version';
  static const String _kLastResultSummary = 'fw_sanity_last_result_summary';

  static String _scopeMac(String mac) {
    final normalized = mac.trim().toLowerCase();
    return normalized.isEmpty ? 'unknown' : normalized;
  }

  static String _k(String mac, String field) => '$_scopePrefix:${_scopeMac(mac)}:$field';
  static const String _scopePrefix = 'post_upgrade';

  Future<void> markReadyToReboot({
    required String mac,
    required String targetVersion,
  }) async {
    await markUpgradeTriggered(mac: mac, targetVersion: targetVersion);
  }

  Future<void> markUpgradeTriggered({
    required String mac,
    required String targetVersion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final keyPending = _k(mac, _kPending);
    final keyTarget = _k(mac, _kTargetVersion);
    final existingPending = prefs.getBool(keyPending) ?? false;
    final existingTarget = (prefs.getString(keyTarget) ?? '').trim();
    final normalizedIncoming = targetVersion.trim();

    if (existingPending && existingTarget == normalizedIncoming) {
      return;
    }

    await prefs.setBool(keyPending, true);
    await prefs.setString(keyTarget, normalizedIncoming);
    await prefs.setInt(_k(mac, _kMarkedAtEpoch), DateTime.now().millisecondsSinceEpoch);
  }

  Future<PostUpgradePendingState> getPendingState(String mac) async {
    final prefs = await SharedPreferences.getInstance();
    return PostUpgradePendingState(
      isPending: prefs.getBool(_k(mac, _kPending)) ?? false,
      targetVersion: prefs.getString(_k(mac, _kTargetVersion)),
      markedAtEpoch: prefs.getInt(_k(mac, _kMarkedAtEpoch)),
      sanityRanForVersion: prefs.getString(_k(mac, _kSanityRanForVersion)),
      lastResultSummary: prefs.getString(_k(mac, _kLastResultSummary)),
    );
  }

  Future<void> markSanityRunCompleted({
    required String mac,
    required String version,
    required Map<String, dynamic> summary,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k(mac, _kSanityRanForVersion), version.trim());
    await prefs.setString(_k(mac, _kLastResultSummary), jsonEncode(summary));
  }

  Future<void> clearPending(String mac) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k(mac, _kPending), false);
    await prefs.remove(_k(mac, _kTargetVersion));
    await prefs.remove(_k(mac, _kMarkedAtEpoch));
  }
}
