import '../models/air_sensor_limits.dart';

/// Evaluates min/max/measured rules for Matter air sensor [readings] maps
/// (endpoint 1 resource names → string values from WebPA).
class AirSensorThresholdEvaluator {
  AirSensorThresholdEvaluator._();

  /// Exposed for [AirSensorLimitsStore] grouping.
  static final RegExp concentrationKey =
      RegExp(r'^(matter\w+Concentration)(Max|Measured|Min)$');

  static double? parseNumeric(String? raw) {
    if (raw == null) return null;
    final t = raw.trim().toLowerCase();
    if (t.isEmpty || t == 'null' || t == '(null)' || t == 'n/a') {
      return null;
    }
    return double.tryParse(t);
  }

  /// Returns human-readable titles for concentration group bases.
  static String titleForConcentrationBase(String base) {
    const map = {
      'matterCo2Concentration': 'CO₂',
      'matterCoConcentration': 'CO',
      'matterFormaldehydeConcentration': 'Formaldehyde',
      'matterNo2Concentration': 'NO₂',
      'matterO3Concentration': 'O₃',
      'matterPm10Concentration': 'PM10',
      'matterPm1Concentration': 'PM1',
      'matterPm25Concentration': 'PM2.5',
      'matterRadonConcentration': 'Radon',
      'matterTvocConcentration': 'TVOC',
    };
    return map[base] ?? base.replaceFirst('matter', '').replaceAll('Concentration', '');
  }

  /// All metrics currently out of range (measured < min or measured > max).
  static List<AirSensorBreach> evaluate(Map<String, String> readings) {
    final out = <AirSensorBreach>[];

    final groups = <String, Map<String, String>>{};
    for (final e in readings.entries) {
      final m = concentrationKey.firstMatch(e.key);
      if (m == null) continue;
      final base = m.group(1)!;
      final suffix = m.group(2)!;
      groups.putIfAbsent(base, () => {});
      groups[base]![suffix] = e.value;
    }

    for (final e in groups.entries) {
      final base = e.key;
      final g = e.value;
      final max = parseNumeric(g['Max']);
      final min = parseNumeric(g['Min']);
      final measured = parseNumeric(g['Measured']);
      if (max == null || min == null || measured == null) continue;
      if (measured < min || measured > max) {
        out.add(AirSensorBreach(
          metricId: base,
          title: '${titleForConcentrationBase(base)} concentration',
          measured: measured,
          min: min,
          max: max,
        ));
      }
    }

    final hp = parseNumeric(readings['matterRelativeHumidityPercent']);
    final hmin = parseNumeric(readings['matterRelativeHumidityMinPercent']);
    final hmax = parseNumeric(readings['matterRelativeHumidityMaxPercent']);
    if (hp != null && hmin != null && hmax != null && (hp < hmin || hp > hmax)) {
      out.add(AirSensorBreach(
        metricId: 'relativeHumidity',
        title: 'Relative humidity',
        measured: hp,
        min: hmin,
        max: hmax,
      ));
    }

    final tc = parseNumeric(readings['matterTemperatureMeasuredC']);
    final tmin = parseNumeric(readings['matterTemperatureMinC']);
    final tmax = parseNumeric(readings['matterTemperatureMaxC']);
    if (tc != null && tmin != null && tmax != null && (tc < tmin || tc > tmax)) {
      out.add(AirSensorBreach(
        metricId: 'temperature',
        title: 'Temperature',
        measured: tc,
        min: tmin,
        max: tmax,
      ));
    }

    return out;
  }

  /// Uses [stored] min/max when present; otherwise falls back to live [readings] Min/Max.
  static List<AirSensorBreach> evaluateWithStoredThresholds(
    Map<String, String> readings,
    Map<String, StoredMinMax> stored,
  ) {
    final out = <AirSensorBreach>[];

    final groups = <String, Map<String, String>>{};
    for (final e in readings.entries) {
      final m = concentrationKey.firstMatch(e.key);
      if (m == null) continue;
      final base = m.group(1)!;
      final suffix = m.group(2)!;
      groups.putIfAbsent(base, () => {});
      groups[base]![suffix] = e.value;
    }

    for (final e in groups.entries) {
      final base = e.key;
      final g = e.value;
      final pair = stored[base];
      final max = pair?.max ?? parseNumeric(g['Max']);
      final min = pair?.min ?? parseNumeric(g['Min']);
      final measured = parseNumeric(g['Measured']);
      if (max == null || min == null || measured == null) continue;
      if (measured < min || measured > max) {
        out.add(AirSensorBreach(
          metricId: base,
          title: '${titleForConcentrationBase(base)} concentration',
          measured: measured,
          min: min,
          max: max,
        ));
      }
    }

    final hp = parseNumeric(readings['matterRelativeHumidityPercent']);
    final hpStored = stored['relativeHumidity'];
    final hmin = hpStored?.min ??
        parseNumeric(readings['matterRelativeHumidityMinPercent']);
    final hmax = hpStored?.max ??
        parseNumeric(readings['matterRelativeHumidityMaxPercent']);
    if (hp != null && hmin != null && hmax != null && (hp < hmin || hp > hmax)) {
      out.add(AirSensorBreach(
        metricId: 'relativeHumidity',
        title: 'Relative humidity',
        measured: hp,
        min: hmin,
        max: hmax,
      ));
    }

    final tc = parseNumeric(readings['matterTemperatureMeasuredC']);
    final tp = stored['temperature'];
    final tmin = tp?.min ?? parseNumeric(readings['matterTemperatureMinC']);
    final tmax = tp?.max ?? parseNumeric(readings['matterTemperatureMaxC']);
    if (tc != null && tmin != null && tmax != null && (tc < tmin || tc > tmax)) {
      out.add(AirSensorBreach(
        metricId: 'temperature',
        title: 'Temperature',
        measured: tc,
        min: tmin,
        max: tmax,
      ));
    }

    return out;
  }
}

class AirSensorBreach {
  final String metricId;
  final String title;
  final double measured;
  final double min;
  final double max;

  AirSensorBreach({
    required this.metricId,
    required this.title,
    required this.measured,
    required this.min,
    required this.max,
  });

  String get body =>
      'Measured ${_fmt(measured)} is outside range ${_fmt(min)} – ${_fmt(max)}';

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2);
  }
}
