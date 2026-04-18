import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../repositories/smart_home_repository.dart';
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

  Future<void> load() async {
    _state = UiState.loading();
    notifyListeners();
    try {
      final sensorState = await _repository.getAirSensorState(nodeId);
      if (sensorState != null) {
        _state = UiState.success(sensorState);
      } else {
        _state = UiState.error('Could not load air sensor');
      }
    } catch (e) {
      _state = UiState.error(e.toString());
    }
    notifyListeners();
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
