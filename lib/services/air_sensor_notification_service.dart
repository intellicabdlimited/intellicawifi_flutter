import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'air_sensor_limits_store.dart';
import 'air_sensor_threshold_evaluator.dart';

const String kAirSensorAlertsEnabledPref = 'air_sensor_alerts_enabled';

/// Local notifications when measured values leave the [min, max] band.
/// Edge-triggered: alerts when a metric transitions from in-range to out-of-range.
class AirSensorNotificationService {
  AirSensorNotificationService._();
  static final AirSensorNotificationService instance =
      AirSensorNotificationService._();

  static const String _channelId = 'air_sensor_thresholds';
  static const String _channelName = 'Air sensor alerts';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Registers channels and the plugin only. Do **not** request runtime permissions
  /// here — calling permission dialogs before the first frame is drawn breaks
  /// Android FlutterActivity predraw (stuck splash / VRI cancelAndRedraw loop).
  /// Use [requestPostPermissions] after UI is visible (e.g. post-frame or user action).
  Future<void> initialize() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Alerts when air sensor readings exceed min/max',
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  Future<void> requestPostPermissions() async {
    if (!_initialized) await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<bool> alertsEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(kAirSensorAlertsEnabledPref) ?? true;
  }

  Future<void> setAlertsEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(kAirSensorAlertsEnabledPref, value);
  }

  String _edgeKey(String nodeId) => 'air_sensor_edge_$nodeId';

  Future<Map<String, String>> _loadEdges(String nodeId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_edgeKey(nodeId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveEdges(String nodeId, Map<String, String> edges) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_edgeKey(nodeId), jsonEncode(edges));
  }

  /// Call after fresh WebPA readings (same rules as [AirSensorThresholdEvaluator]).
  Future<void> processReading({
    required String nodeId,
    required String deviceLabel,
    required Map<String, String> readings,
  }) async {
    if (!_initialized) await initialize();
    if (!await alertsEnabled()) return;

    final stored = await AirSensorLimitsStore.instance.getLimits(nodeId);
    final breaches = stored.isEmpty
        ? AirSensorThresholdEvaluator.evaluate(readings)
        : AirSensorThresholdEvaluator.evaluateWithStoredThresholds(readings, stored);
    final breachIds = {for (final b in breaches) b.metricId};

    final edges = await _loadEdges(nodeId);
    final allMetricIds = <String>{...edges.keys, ...breachIds};

    var changed = false;
    for (final id in allMetricIds) {
      final isBad = breachIds.contains(id);
      final prev = edges[id];
      final wasBad = prev == 'bad';

      if (isBad && !wasBad) {
        final b = breaches.firstWhere((x) => x.metricId == id);
        await _showNotification(
          nodeId: nodeId,
          metricId: id,
          title: deviceLabel,
          body: '${b.title}: ${b.body}',
        );
        edges[id] = 'bad';
        changed = true;
      } else if (!isBad) {
        if (prev != 'ok') {
          edges[id] = 'ok';
          changed = true;
        }
      }
    }

    if (changed) await _saveEdges(nodeId, edges);
  }

  Future<void> _showNotification({
    required String nodeId,
    required String metricId,
    required String title,
    required String body,
  }) async {
    final id = (nodeId.hashCode ^ metricId.hashCode).abs() % 0x7FFFFFFF;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Air sensor min/max threshold alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      id,
      title,
      body,
      details,
    );
  }

  /// Clears edge state for a device (e.g. after unpair).
  Future<void> clearEdgeState(String nodeId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_edgeKey(nodeId));
  }
}
