import 'package:flutter/foundation.dart';

import '../models/air_sensor_limits.dart';
import '../models/models.dart';
import '../repositories/smart_home_repository.dart';
import '../services/air_sensor_limits_store.dart';
import '../services/air_sensor_notification_service.dart';
import '../utils/ui_state.dart';

class AirSensorViewModel extends ChangeNotifier {
  AirSensorViewModel({required this.nodeId});

  static const String labelUpdatedMessage = 'Label updated';

  final SmartHomeRepository _repository = SmartHomeRepository();
  final String nodeId;

  UiState<AirSensorState> _state = UiState.loading();
  UiState<AirSensorState> get state => _state;

  bool _isOperationLoading = false;
  bool get isOperationLoading => _isOperationLoading;

  UiState<String>? _operationResult;
  UiState<String>? get operationResult => _operationResult;

  Map<String, StoredMinMax> _limits = {};
  Map<String, StoredMinMax> get limits => Map.unmodifiable(_limits);

  Future<void> load() async {
    _state = UiState.loading();
    notifyListeners();
    try {
      final sensorState = await _repository.getAirSensorState(nodeId);
      if (sensorState != null) {
        await AirSensorLimitsStore.instance.seedFromReadingsIfEmpty(nodeId, sensorState.readings);
        _limits = await AirSensorLimitsStore.instance.getLimits(nodeId);
        _state = UiState.success(sensorState);

        await AirSensorNotificationService.instance.processReading(
          nodeId: nodeId,
          deviceLabel: sensorState.label,
          readings: sensorState.readings,
        );
      } else {
        _state = UiState.error('Could not load air sensor');
      }
    } catch (e) {
      _state = UiState.error(e.toString());
    }
    notifyListeners();
  }

  /// Step for +/- controls (concentration vs % / °C).
  double stepForMetric(String metricId) {
    if (metricId == 'relativeHumidity' || metricId == 'temperature') {
      return 0.1;
    }
    return 1.0;
  }

  Future<void> adjustLimit(String metricId, bool isMax, double delta) async {
    final pair = _limits[metricId];
    if (pair == null) return;

    var nmin = pair.min;
    var nmax = pair.max;
    if (isMax) {
      nmax += delta;
    } else {
      nmin += delta;
    }
    if (nmin > nmax) {
      if (isMax) {
        nmin = nmax;
      } else {
        nmax = nmin;
      }
    }

    await AirSensorLimitsStore.instance.setPair(
      nodeId,
      metricId,
      StoredMinMax(min: nmin, max: nmax),
    );
    _limits = await AirSensorLimitsStore.instance.getLimits(nodeId);
    notifyListeners();

    if (_state.status == UiStatus.success && _state.data != null) {
      final st = _state.data!;
      await AirSensorNotificationService.instance.processReading(
        nodeId: nodeId,
        deviceLabel: st.label,
        readings: st.readings,
      );
      notifyListeners();
    }
  }

  Future<void> setLabel(String label) async {
    _isOperationLoading = true;
    notifyListeners();
    try {
      final ok = await _repository.setAirSensorLabel(nodeId, label);
      if (ok) {
        _operationResult = UiState.success(labelUpdatedMessage);
        if (_state.status == UiStatus.success && _state.data != null) {
          final prev = _state.data!;
          final nextReadings = Map<String, String>.from(prev.readings);
          nextReadings['label'] = label;
          _state = UiState.success(prev.copyWith(label: label, readings: nextReadings));
        }
      } else {
        _operationResult = UiState.error('Failed to update label');
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }
    _isOperationLoading = false;
    notifyListeners();
  }

  void clearOperationResult() {
    _operationResult = null;
    notifyListeners();
  }
}
