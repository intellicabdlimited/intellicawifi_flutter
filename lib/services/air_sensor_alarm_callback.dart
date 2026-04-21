import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../repositories/smart_home_repository.dart';
import 'air_sensor_notification_service.dart';

/// Android [AndroidAlarmManager] entry point (separate isolate).
@pragma('vm:entry-point')
Future<void> airSensorPeriodicAlarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    await AirSensorNotificationService.instance.initialize();
    if (!await AirSensorNotificationService.instance.alertsEnabled()) return;

    final repo = SmartHomeRepository();
    final devices = await repo.listDevices();
    final sensors = devices.where((d) => d.deviceClass == 'sensor').toList();

    for (final d in sensors) {
      final state = await repo.getAirSensorState(d.nodeId);
      if (state == null) continue;
      await AirSensorNotificationService.instance.processReading(
        nodeId: d.nodeId,
        deviceLabel: d.label,
        readings: state.readings,
      );
    }
  } catch (_) {}
}
