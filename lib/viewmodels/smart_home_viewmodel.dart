import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../repositories/smart_home_repository.dart';
import '../utils/ui_state.dart';

class SmartHomeViewModel extends ChangeNotifier {
  final SmartHomeRepository _repository = SmartHomeRepository();

  UiState<List<SmartDevice>> _devices = UiState.loading();
  UiState<List<SmartDevice>> get devices => _devices;

  UiState<String>? _operationResult;
  UiState<String>? get operationResult => _operationResult;

  bool _isOperationLoading = false;
  bool get isOperationLoading => _isOperationLoading;

  String? _ssid;
  String? _password;
  String get ssid => _ssid ?? "";
  String get password => _password ?? "";
  bool get isWifiConfigured => _ssid != null && _ssid!.isNotEmpty;

  void loadDevices() async {
    _devices = UiState.loading();
    notifyListeners();
    try {
      final apiDevices = await _repository.listDevices();
      final loadedDevices = await Future.wait(
        apiDevices.map((d) async {
           var device = await _repository.getDeviceConfig(d);
           
           final timerInfo = await _repository.getDeviceTimerInfo(device.nodeId);
           if (timerInfo != null) {
              final targetEpoch = timerInfo['targetEpoch'] as int;
              final action = timerInfo['action'] as String;
              final now = DateTime.now().millisecondsSinceEpoch;
              
              if (now >= targetEpoch) {
                 final isTurningOn = action.toLowerCase() == "on";
                 device = device.copyWith(isOn: isTurningOn);
                 await _repository.saveDeviceConfig(device);
                 await _repository.removeDeviceTimerInfo(device.nodeId);
              } else {
                 final remainingMs = targetEpoch - now;
                 if (remainingMs > 0) {
                    _scheduleLocalTimerUpdate(device.nodeId, remainingMs, action);
                 }
              }
           }
           return device;
        })
      );
      _devices = UiState.success(loadedDevices);
    } catch (e) {
      _devices = UiState.error(e.toString());
    }
    notifyListeners();
  }
  Future<void> loadWifiConfig() async {
    try {
      final config = await _repository.getBartonWifiConfig();
      if (config.isNotEmpty) {
        _ssid = config[0];
        _password = config[1];
      } else {
        _ssid = null;
        _password = null;
      }
    } catch (e) {
      _ssid = null;
      _password = null;
    }
    notifyListeners();
  }

  Future<bool> saveWifiConfig(String ssid, String password) async {
    _isOperationLoading = true;
    notifyListeners();
    
    bool success = false;
    try {
      success = await _repository.setBartonWifiConfig(ssid, password);
      if (success) {
        _ssid = ssid;
        _password = password;
        _operationResult = UiState.success("WiFi configured successfully");
      } else {
        _operationResult = UiState.error("Failed to configure WiFi");
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }
    
    _isOperationLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> toggleDevice(String nodeId, bool currentStatus) async {
    final setLight = currentStatus ? "OFF" : "ON";
    _isOperationLoading = true;
    notifyListeners();

    try {
      final success = await _repository.setDeviceStatus("$nodeId,$setLight");
      if (success) {
        if (_devices.status == UiStatus.success) {
           final currentList = _devices.data!;
           final updatedList = <SmartDevice>[];
           
           for (var d in currentList) {
             if (d.nodeId == nodeId) {
               final updatedDevice = d.copyWith(isOn: !currentStatus);
               await _repository.saveDeviceConfig(updatedDevice);
               updatedList.add(updatedDevice);
             } else {
               updatedList.add(d);
             }
           }
           _devices = UiState.success(updatedList);
        }
        _operationResult = UiState.success("Device ${!currentStatus ? "turned on" : "turned off"}");
      } else {
        _operationResult = UiState.error("Failed to toggle device");
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }
    
    _isOperationLoading = false;
    notifyListeners();
  }

  Future<void> removeDevice(String nodeId) async {
    _isOperationLoading = true;
    notifyListeners();

    if (!isWifiConfigured) {
       _operationResult = UiState.error("WiFi not configured. Cannot remove device.");
       _isOperationLoading = false;
       notifyListeners();
       return;
    }

    try {
      final success = await _repository.removeDevice(nodeId);
      if (success) {
        await _repository.removeDeviceConfig(nodeId);
        _operationResult = UiState.success("Device removed successfully");
        await Future.delayed(const Duration(seconds: 5));
        loadDevices();
      } else {
         _operationResult = UiState.error("Failed to remove device");
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }

    _isOperationLoading = false;
    notifyListeners();
  }
  
  Future<void> commissionDevice(String pairingCode) async {
    _isOperationLoading = true;
    notifyListeners();

    try {
      final success = await _repository.commissionDevice(pairingCode);
      if (success) {
        // Wait 23 seconds for the device to join
        await Future.delayed(const Duration(seconds: 23));
        
        await _repository.setBartonTemp("commission");
        
        await Future.delayed(const Duration(seconds: 1));
        
        final statusAndNode = await _repository.getBartonTemp();
        final parts = statusAndNode.split(',');

        final String status = parts.isNotEmpty ? parts[0] : '';
        final String nodeId = parts.length > 1 ? parts[1] : '';

        print('status: $status');
        print('nodeId: $nodeId');

        if (status == "commissionedsuccessfully") {
          _operationResult = UiState.success("Device commissioned successfully");
        } else {
           _operationResult = UiState.error("Failed to commission device");
        }
      } else {
        _operationResult = UiState.error("Failed to initiate commissioning");
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }
    
    loadDevices();
    
    _isOperationLoading = false;
    notifyListeners();
  }

  Future<void> setDeviceColor(String nodeId, int hueValue) async {
    _isOperationLoading = true;
    notifyListeners();

    try {
      final value = "$nodeId,$hueValue";
      final success = await _repository.setDeviceColor(value);
      if (success) {
         if (_devices.status == UiStatus.success) {
           final currentList = _devices.data!;
           final updatedList = <SmartDevice>[];
           
           for (var d in currentList) {
             if (d.nodeId == nodeId) {
               final updatedDevice = d.copyWith(hue: hueValue);
               await _repository.saveDeviceConfig(updatedDevice);
               updatedList.add(updatedDevice);
             } else {
               updatedList.add(d);
             }
           }
           _devices = UiState.success(updatedList);
        }
        _operationResult = UiState.success("Color updated successfully");
      } else {
        _operationResult = UiState.error("Failed to update color");
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }

    _isOperationLoading = false;
    notifyListeners();
  }

  Future<void> setDeviceBrightness(String nodeId, int brightnessPercent) async {
    _isOperationLoading = true;
    notifyListeners();

    try {
      // Convert 0-100 to 0-254
      final brightnessApi = ((brightnessPercent / 100.0) * 254).toInt().toString();
      final value = "$nodeId,$brightnessApi";
      final success = await _repository.setDeviceBrightness(value);
      if (success) {
         if (_devices.status == UiStatus.success) {
           final currentList = _devices.data!;
           final updatedList = <SmartDevice>[];
           
           for (var d in currentList) {
             if (d.nodeId == nodeId) {
               final updatedDevice = d.copyWith(brightness: brightnessPercent);
               await _repository.saveDeviceConfig(updatedDevice);
               updatedList.add(updatedDevice);
             } else {
               updatedList.add(d);
             }
           }
           _devices = UiState.success(updatedList);
        }
        _operationResult = UiState.success("Brightness updated successfully");
      } else {
        _operationResult = UiState.error("Failed to update brightness");
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }

    _isOperationLoading = false;
    notifyListeners();
  }

  Future<void> setDeviceSaturation(String nodeId, int saturationPercent) async {
    _isOperationLoading = true;
    notifyListeners();

    try {
      // Convert 0-100 to 0-254
      final saturationApi = ((saturationPercent / 100.0) * 254).toInt().toString();
      final value = "$nodeId,$saturationApi";
      final success = await _repository.setDeviceSaturation(value);
      if (success) {
         if (_devices.status == UiStatus.success) {
           final currentList = _devices.data!;
           final updatedList = <SmartDevice>[];
           
           for (var d in currentList) {
             if (d.nodeId == nodeId) {
               final updatedDevice = d.copyWith(saturation: saturationPercent);
               await _repository.saveDeviceConfig(updatedDevice);
               updatedList.add(updatedDevice);
             } else {
               updatedList.add(d);
             }
           }
           _devices = UiState.success(updatedList);
        }
        _operationResult = UiState.success("Saturation updated successfully");
      } else {
        _operationResult = UiState.error("Failed to update saturation");
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }

    _isOperationLoading = false;
    notifyListeners();
  }

  Future<void> setDeviceLabel(String nodeId, String label) async {
    _isOperationLoading = true;
    notifyListeners();

    try {
      final success = await _repository.setDeviceLabel(nodeId, label);
      if (success) {
        _operationResult = UiState.success("Label updated successfully");
        // Refresh the device list
        loadDevices();
      } else {
        _operationResult = UiState.error("Failed to update label");
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }

    _isOperationLoading = false;
    notifyListeners();
  }

  void _scheduleLocalTimerUpdate(String nodeId, int durationMs, String action) {
     Future.delayed(Duration(milliseconds: durationMs), () async {
           if (_devices.status == UiStatus.success) {
             final currentList = _devices.data!;
             final updatedList = <SmartDevice>[];
             final isTurningOn = action.toLowerCase() == "on";
             
             bool foundAndUpdated = false;
             for (var d in currentList) {
               if (d.nodeId == nodeId) {
                 final updatedDevice = d.copyWith(isOn: isTurningOn);
                 await _repository.saveDeviceConfig(updatedDevice);
                 await _repository.removeDeviceTimerInfo(nodeId);
                 updatedList.add(updatedDevice);
                 foundAndUpdated = true;
               } else {
                 updatedList.add(d);
               }
             }

             if (foundAndUpdated) {
                _devices = UiState.success(updatedList);
                notifyListeners();
             }
           }
    });
  }

  Future<void> setDeviceTimer(String nodeId, int timeInSeconds, String action) async {
    _isOperationLoading = true;
    notifyListeners();

    try {
      final success = await _repository.setDeviceTimer(nodeId, timeInSeconds, action);
      if (success) {
        _operationResult = UiState.success("Timer set successfully");

        final targetEpoch = DateTime.now().millisecondsSinceEpoch + (timeInSeconds * 1000);
        await _repository.saveDeviceTimerInfo(nodeId, targetEpoch, action);

        _scheduleLocalTimerUpdate(nodeId, timeInSeconds * 1000, action);

      } else {
        _operationResult = UiState.error("Failed to set timer");
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

  /// Starts Zigbee discovery (WebPA Device.Barton.temp1 = "discoverStart light").
  Future<bool> startZigbeeDiscovery() async {
    try {
      return await _repository.setBartonTemp1("discoverStart light");
    } catch (e) {
      return false;
    }
  }

  /// Stops Zigbee discovery (WebPA Device.Barton.temp1 = "discoverStop"), waits 2s, then refreshes device list.
  Future<void> stopZigbeeDiscoveryAndRefresh() async {
    try {
      await _repository.setBartonTemp1("discoverStop");
      await Future.delayed(const Duration(seconds: 2));
      loadDevices();
    } catch (_) {
      loadDevices();
    }
  }

  // --- Zigbee light controls (writeResource APIs) ---

  Future<void> toggleZigbeeDevice(String nodeId, bool currentStatus) async {
    _isOperationLoading = true;
    notifyListeners();
    try {
      final success = await _repository.setZigbeeIsOn(nodeId, !currentStatus);
      if (success && _devices.status == UiStatus.success) {
        final currentList = _devices.data!;
        final updatedList = currentList.map((d) {
          if (d.nodeId == nodeId) return d.copyWith(isOn: !currentStatus);
          return d;
        }).toList();
        _devices = UiState.success(updatedList);
        for (var d in updatedList) {
          if (d.nodeId == nodeId) await _repository.saveDeviceConfig(d);
        }
        _operationResult = UiState.success("Device ${!currentStatus ? "turned on" : "turned off"}");
      } else if (!success) {
        _operationResult = UiState.error("Failed to toggle device");
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }
    _isOperationLoading = false;
    notifyListeners();
  }

  /// [percent] 1-100, mapped to 153-500.
  Future<void> setZigbeeColorTemp(String nodeId, int percent) async {
    _isOperationLoading = true;
    notifyListeners();
    try {
      final value = 153 + (347 * (percent.clamp(1, 100) / 100)).round();
      final success = await _repository.setZigbeeColorTemp(nodeId, value);
      if (success) {
        await _repository.saveZigbeeColorTempState(nodeId, percent.clamp(1, 100));
        _operationResult = UiState.success("Color temperature updated");
      } else {
        _operationResult = UiState.error("Failed to set color temperature");
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }
    _isOperationLoading = false;
    notifyListeners();
  }

  Future<void> setZigbeeColorXY(String nodeId, double x, double y) async {
    _isOperationLoading = true;
    notifyListeners();
    try {
      final success = await _repository.setZigbeeColorXY(nodeId, x, y);
      if (success) {
        await _repository.saveZigbeeColorXYState(nodeId, x, y);
        _operationResult = UiState.success("Color updated successfully");
      } else {
        _operationResult = UiState.error("Failed to update color");
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }
    _isOperationLoading = false;
    notifyListeners();
  }

  /// [percent] 0-100, mapped to 0-254.
  Future<void> setZigbeeBrightness(String nodeId, int percent) async {
    _isOperationLoading = true;
    notifyListeners();
    try {
      final level = ((percent.clamp(0, 100) / 100.0) * 254).round();
      final success = await _repository.setZigbeeCurrentLevel(nodeId, level);
      if (success && _devices.status == UiStatus.success) {
        final currentList = _devices.data!;
        final updatedList = <SmartDevice>[];
        for (var d in currentList) {
          if (d.nodeId == nodeId) {
            final updatedDevice = d.copyWith(brightness: percent);
            updatedList.add(updatedDevice);
            await _repository.saveDeviceConfig(updatedDevice);
          } else {
            updatedList.add(d);
          }
        }
        _devices = UiState.success(updatedList);
        _operationResult = UiState.success("Brightness updated successfully");
      } else if (!success) {
        _operationResult = UiState.error("Failed to update brightness");
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }
    _isOperationLoading = false;
    notifyListeners();
  }

  Future<ZigbeeSavedState?> getZigbeeState(String nodeId) async =>
      _repository.getZigbeeState(nodeId);

  Future<void> setZigbeeLabel(String nodeId, String label) async {
    _isOperationLoading = true;
    notifyListeners();
    try {
      final success = await _repository.setZigbeeLabel(nodeId, label);
      if (success) {
        _operationResult = UiState.success("Label updated successfully");
        loadDevices();
      } else {
        _operationResult = UiState.error("Failed to update label");
      }
    } catch (e) {
      _operationResult = UiState.error(e.toString());
    }
    _isOperationLoading = false;
    notifyListeners();
  }
}
