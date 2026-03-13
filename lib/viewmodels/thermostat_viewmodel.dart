import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../repositories/smart_home_repository.dart';
import '../utils/ui_state.dart';

class ThermostatViewModel extends ChangeNotifier {
  final SmartHomeRepository _repository = SmartHomeRepository();

  final String nodeId;
  ThermostatViewModel({required this.nodeId});

  UiState<ThermostatState> _state = UiState.loading();
  UiState<ThermostatState> get state => _state;

  bool _isOperationLoading = false;
  bool get isOperationLoading => _isOperationLoading;

  UiState<String>? _operationResult;
  UiState<String>? get operationResult => _operationResult;

  Future<void> load() async {
    _state = UiState.loading();
    notifyListeners();
    try {
      final thermostatState = await _repository.getThermostatState(nodeId);
      if (thermostatState != null) {
        _state = UiState.success(thermostatState);
      } else {
        _state = UiState.error('Could not load thermostat');
      }
    } catch (e) {
      _state = UiState.error(e.toString());
    }
    notifyListeners();
  }

  Future<void> setHeatSetpoint(double valueC) async {
    final clamped = valueC.clamp(
      ThermostatState.heatSetpointMinC,
      ThermostatState.heatSetpointMaxC,
    );
    _isOperationLoading = true;
    notifyListeners();
    try {
      final ok = await _repository.setThermostatHeatSetpoint(nodeId, clamped);
      if (ok && _state.status == UiStatus.success) {
        _state = UiState.success(_state.data!.copyWith(heatSetpoint: clamped));
        _operationResult = UiState.success('Heat setpoint updated');
      } else {
        _operationResult = UiState.error('Failed to set heat setpoint');
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }
    _isOperationLoading = false;
    notifyListeners();
  }

  Future<void> setCoolSetpoint(double valueC) async {
    final clamped = valueC.clamp(
      ThermostatState.coolSetpointMinC,
      ThermostatState.coolSetpointMaxC,
    );
    _isOperationLoading = true;
    notifyListeners();
    try {
      final ok = await _repository.setThermostatCoolSetpoint(nodeId, clamped);
      if (ok && _state.status == UiStatus.success) {
        _state = UiState.success(_state.data!.copyWith(coolSetpoint: clamped));
        _operationResult = UiState.success('Cool setpoint updated');
      } else {
        _operationResult = UiState.error('Failed to set cool setpoint');
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }
    _isOperationLoading = false;
    notifyListeners();
  }

  Future<void> setSystemMode(String mode) async {
    if (!ThermostatState.systemModes.contains(mode)) return;
    _isOperationLoading = true;
    notifyListeners();
    try {
      final ok = await _repository.setThermostatSystemMode(nodeId, mode);
      if (ok && _state.status == UiStatus.success) {
        _state = UiState.success(_state.data!.copyWith(systemMode: mode));
        _operationResult = UiState.success('Mode set to $mode');
      } else {
        _operationResult = UiState.error('Failed to set mode');
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
