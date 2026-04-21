import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/air_sensor_limits.dart';

/// User-editable min/max for threshold alerts (SharedPreferences per node).
class AirSensorLimitsStore {
  AirSensorLimitsStore._();
  static final AirSensorLimitsStore instance = AirSensorLimitsStore._();

  static final RegExp _conc =
      RegExp(r'^(matter\w+Concentration)(Max|Measured|Min)$');

  static String _key(String nodeId) => 'air_sensor_limits_v1_$nodeId';

  static double? _parseNum(String? raw) {
    if (raw == null) return null;
    final t = raw.trim().toLowerCase();
    if (t.isEmpty || t == 'null' || t == '(null)' || t == 'n/a') {
      return null;
    }
    return double.tryParse(t);
  }

  Future<Map<String, StoredMinMax>> getLimits(String nodeId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key(nodeId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(
          k,
          StoredMinMax.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(String nodeId, Map<String, StoredMinMax> data) async {
    final p = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      data.map((k, v) => MapEntry(k, v.toJson())),
    );
    await p.setString(_key(nodeId), encoded);
  }

  Future<void> setPair(String nodeId, String metricId, StoredMinMax pair) async {
    final cur = await getLimits(nodeId);
    cur[metricId] = pair;
    await _save(nodeId, cur);
  }

  /// First successful [printDevice]: copy device Min/Max into prefs if none saved yet.
  Future<void> seedFromReadingsIfEmpty(String nodeId, Map<String, String> readings) async {
    final existing = await getLimits(nodeId);
    if (existing.isNotEmpty) return;

    final seeded = _extractLimitsFromReadings(readings);
    if (seeded.isEmpty) return;
    await _save(nodeId, seeded);
  }

  Map<String, StoredMinMax> _extractLimitsFromReadings(Map<String, String> readings) {
    final out = <String, StoredMinMax>{};

    final groups = <String, Map<String, String>>{};
    for (final e in readings.entries) {
      final m = _conc.firstMatch(e.key);
      if (m == null) continue;
      final base = m.group(1)!;
      final suffix = m.group(2)!;
      groups.putIfAbsent(base, () => {});
      groups[base]![suffix] = e.value;
    }

    for (final e in groups.entries) {
      final g = e.value;
      final minV = _parseNum(g['Min']);
      final maxV = _parseNum(g['Max']);
      if (minV != null && maxV != null) {
        out[e.key] = StoredMinMax(min: minV, max: maxV);
      }
    }

    final hmin = _parseNum(readings['matterRelativeHumidityMinPercent']);
    final hmax = _parseNum(readings['matterRelativeHumidityMaxPercent']);
    if (hmin != null && hmax != null) {
      out['relativeHumidity'] = StoredMinMax(min: hmin, max: hmax);
    }

    final tmin = _parseNum(readings['matterTemperatureMinC']);
    final tmax = _parseNum(readings['matterTemperatureMaxC']);
    if (tmin != null && tmax != null) {
      out['temperature'] = StoredMinMax(min: tmin, max: tmax);
    }

    return out;
  }

  Future<void> clear(String nodeId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key(nodeId));
  }
}
