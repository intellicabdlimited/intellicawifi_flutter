import 'package:flutter/foundation.dart';
import '../repositories/smart_home_repository.dart';
import '../utils/ui_state.dart';

class DoorLockViewModel extends ChangeNotifier {
  DoorLockViewModel({required this.nodeId});

  static const String labelUpdatedMessage = 'Label updated';

  final SmartHomeRepository _repository = SmartHomeRepository();
  final String nodeId;

  UiState<bool> _state = UiState.loading();
  /// `true` means locked.
  UiState<bool> get state => _state;

  bool _isOperationLoading = false;
  bool get isOperationLoading => _isOperationLoading;

  UiState<String>? _operationResult;
  UiState<String>? get operationResult => _operationResult;

  Future<void> load() async {
    _state = UiState.loading();
    notifyListeners();
    try {
      final locked = await _repository.getDoorLockLocked(nodeId);
      // Matter often reports null until first write; default to unlocked (false).
      _state = UiState.success(locked ?? false);
    } catch (e) {
      _state = UiState.error(e.toString());
    }
    notifyListeners();
  }

  Future<void> setLocked(bool locked) async {
    _isOperationLoading = true;
    notifyListeners();
    try {
      final ok = await _repository.setDoorLocked(nodeId, locked);
      if (!ok) {
        _operationResult = UiState.error('Failed to update lock');
        _isOperationLoading = false;
        notifyListeners();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 400));
      final verified = await _repository.getDoorLockLocked(nodeId);
      _state = UiState.success(verified ?? locked);
      _operationResult = UiState.success(locked ? 'Door locked' : 'Door unlocked');
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }
    _isOperationLoading = false;
    notifyListeners();
  }

  Future<void> setLabel(String label) async {
    _isOperationLoading = true;
    notifyListeners();
    try {
      final ok = await _repository.setDoorLockLabel(nodeId, label);
      if (ok) {
        _operationResult = UiState.success(labelUpdatedMessage);
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
