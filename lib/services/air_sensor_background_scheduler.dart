import 'dart:io' show Platform;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'air_sensor_alarm_callback.dart';

/// Android-only: fires [airSensorPeriodicAlarmCallback] every 2 minutes while alerts are enabled.
class AirSensorBackgroundScheduler {
  AirSensorBackgroundScheduler._();

  /// Unique alarm id (must stay stable across app versions).
  static const int alarmId = 90210;

  static const Duration interval = Duration(minutes: 2);

  /// Call once from [main] before [runApp] (Android only no-op on other platforms).
  static Future<void> initializePlugin() async {
    if (!Platform.isAndroid) return;
    await AndroidAlarmManager.initialize();
  }

  static Future<void> registerPeriodic() async {
    if (!Platform.isAndroid) return;
    await AndroidAlarmManager.cancel(alarmId);
    await AndroidAlarmManager.periodic(
      interval,
      alarmId,
      airSensorPeriodicAlarmCallback,
      wakeup: true,
      rescheduleOnReboot: true,
      exact: true,
      allowWhileIdle: true,
    );
  }

  static Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    await AndroidAlarmManager.cancel(alarmId);
  }

  /// Enables or disables the 2‑minute background poll.
  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    if (enabled) {
      await registerPeriodic();
    } else {
      await cancel();
    }
  }
}
