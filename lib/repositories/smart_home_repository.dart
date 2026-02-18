import '../api/api_service.dart';
import '../models/models.dart';
import '../utils/router_mac_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartHomeRepository {
  final ApiService _api = ApiService();

  Future<List<SmartDevice>> listDevices() async {
    final deviceMac = await RouterMacManager.getMac();
    try {
      final response = await _api.getDeviceParameter(deviceMac, "Device.Light.ListDevice");
      final value = response.parameters?.firstOrNull?.getStringValue();
      
      if (value == null || value.isEmpty || value == "N/A") {
        return [];
      }
      return _parseDeviceList(value);
    } catch (e) {
      // Logic from Kotlin: if empty list executed (not sure if error or empty string)
      return [];
    }
  }
  
  // Reuse getDeviceParameter but looking for specific status
  Future<bool> getDeviceStatus(String nodeId) async {
    final deviceMac = await RouterMacManager.getMac();
    try {
      final response = await _api.getDeviceParameter(deviceMac, "Device.Light.Status");
      final status = response.parameters?.firstOrNull?.getStringValue() ?? "OFF";
      return status == "ON";
    } catch (e) {
      return false;
    }
  }

  Future<bool> setDeviceStatus(String value) async {
    return _sendSetRequest("Device.Light.Status", value);
  }

  Future<bool> commissionDevice(String value) async {
    return _sendSetRequest("Device.Light.Commission", value);
  }

  Future<bool> removeDevice(String value) async {
    return _sendSetRequest("Device.Light.Remove", value);
  }

  Future<bool> setDeviceColor(String hueValue) async {
    return _sendSetRequest("Device.Light.Color", hueValue);
  }

  Future<bool> setDeviceBrightness(String value) async {
    return _sendSetRequest("Device.Light.Level", value);
  }

  Future<bool> setDeviceSaturation(String saturation) async {
    return _sendSetRequest("Device.Light.Saturation", saturation);
  }

  Future<bool> setDeviceLabel(String nodeId, String label) async {
    final value = "$nodeId,$label";
    return _sendSetRequest("Device.Light.Label", value);
  }

  Future<bool> setDeviceTimer(String nodeId, int timeInSeconds, String action) async {
    final value = "$nodeId,$timeInSeconds,$action";
    return _sendSetRequest("Device.Light.Timer", value);
  }

  Future<List<String>> getBartonWifiConfig() async {
    final deviceMac = await RouterMacManager.getMac();
    try {
      final response = await _api.getDeviceParameter(deviceMac, "Device.Barton.SSID");
      final value = response.parameters?.firstOrNull?.getStringValue();

      if (value == null || value.isEmpty || value == "N/A") {
        return [];
      }
      
      // Split by comma. Assuming format "ssid,password"
      final parts = value.split(',');
      if (parts.length >= 2) {
        // changing join logic in case password has commas, though prompt implies simple split
        final ssid = parts[0];
        final password = parts.sublist(1).join(','); 
        return [ssid, password];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> setBartonWifiConfig(String ssid, String password) async {
    return _sendSetRequest("Device.Barton.SSID", "$ssid,$password");
  }

  Future<String> getBartonTemp() async {
    final deviceMac = await RouterMacManager.getMac();
    try {
      final response = await _api.getDeviceParameter(deviceMac, "Device.Barton.temp");
      return response.parameters?.firstOrNull?.getStringValue() ?? "";
    } catch (e) {
      return "";
    }
  }

  Future<bool> setBartonTemp(String value) async {
    return _sendSetRequest("Device.Barton.temp", value);
  }

  Future<String> getDeviceLightClass() async {
    final deviceMac = await RouterMacManager.getMac();
    try {
      // User specified curl: curl -H ... -i "https://.../config?names=Device.Light.Class"
      final response = await _api.getDeviceParameter(deviceMac, "Device.Light.Class");
      return response.parameters?.firstOrNull?.getStringValue() ?? "";
    } catch (e) {
      return "";
    }
  }

  Future<bool> _sendSetRequest(String name, String value) async {
    final deviceMac = await RouterMacManager.getMac();
    final req = SetParameterRequest(
      parameters: [
        SetParameter(name: name, value: value, dataType: 0)
      ],
    );

    try {
      final response = await _api.setDeviceParameter(deviceMac, req);
       // Check for "Success" or 520
       if (response.statusCode == 200) {
         return true;
       } else {
         return false;
       }
       // final respValue = response.parameters?.firstOrNull?.getStringValue();
       // return respValue == "Success";
    } catch (e) {
      throw Exception("Failed to set parameter: $e");
    }
  }

  List<SmartDevice> _parseDeviceList(String raw) {
    if (raw.contains("No devices") || raw.trim() == "barton-core>") {
        return [];
    }

    // Check if it's the new verbose format (e.g. "2470ed7a47084a67: Class: light" then "Label: Matter Light")
    if (raw.contains("Class:")) {
      final lines = raw.split('\n');
      final devices = <SmartDevice>[];
      String? currentId;

      final idAndClassRegex = RegExp(r'^\s*([0-9a-fA-F]+):\s*Class:\s*(\w+)');
      final labelRegex = RegExp(r'Label:\s*(.*)');

      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed.startsWith("barton-core>")) continue;

        final idClassMatch = idAndClassRegex.firstMatch(line);
        if (idClassMatch != null) {
          currentId = idClassMatch.group(1);
          final deviceClass = (idClassMatch.group(2) ?? "light").toLowerCase();
          if (currentId != null) {
            devices.add(SmartDevice(
              nodeId: currentId,
              label: "Unknown Device",
              deviceClass: deviceClass,
            ));
          }
        } else if (currentId != null && line.contains("Label:")) {
          final labelMatch = labelRegex.firstMatch(line);
          if (labelMatch != null) {
            var label = labelMatch.group(1)?.trim() ?? "Unknown Device";
            if (label.endsWith(',')) {
              label = label.substring(0, label.length - 1);
            }
            if (devices.isNotEmpty && devices.last.nodeId == currentId) {
              devices[devices.length - 1] = devices.last.copyWith(label: label);
            }
          }
        }
      }
      return devices;
    } else {
      // Legacy format (comma/space separated IDs)
      return raw
          .split(RegExp(r'[, \n\t]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && s != "barton-core>")
          .map((id) => SmartDevice(nodeId: id, deviceClass: "light"))
          .toList();
    }
  }
  Future<void> saveDeviceConfig(SmartDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "device_config_${device.nodeId}";
    final value = "${device.isOn},${device.hue},${device.brightness},${device.saturation}";
    await prefs.setString(key, value);
  }

  Future<SmartDevice> getDeviceConfig(SmartDevice deviceResultFromApi) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "device_config_${deviceResultFromApi.nodeId}";
    final value = prefs.getString(key);
    
    if (value != null && value.isNotEmpty) {
       final parts = value.split(',');
       if (parts.length >= 4) {
         final isOn = parts[0] == 'true';
         final hue = int.tryParse(parts[1]) ?? 0;
         final brightness = int.tryParse(parts[2]) ?? 50;
         final saturation = int.tryParse(parts[3]) ?? 50;
         
         return deviceResultFromApi.copyWith(
           isOn: isOn,
           hue: hue,
           brightness: brightness,
           saturation: saturation,
         );
       }
    }
    return deviceResultFromApi;
  }
  
  Future<void> removeDeviceConfig(String nodeId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "device_config_$nodeId";
    await prefs.remove(key);
  }

  Future<void> saveDeviceTimerInfo(String nodeId, int targetEpoch, String action) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "device_timer_$nodeId";
    // Format: targetEpoch,action
    await prefs.setString(key, "$targetEpoch,$action");
  }

  Future<Map<String, dynamic>?> getDeviceTimerInfo(String nodeId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "device_timer_$nodeId";
    final value = prefs.getString(key);
    if (value != null && value.isNotEmpty) {
      final parts = value.split(',');
      if (parts.length >= 2) {
        return {
          'targetEpoch': int.tryParse(parts[0]) ?? 0,
          'action': parts[1],
        };
      }
    }
    return null;
  }

  Future<void> removeDeviceTimerInfo(String nodeId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "device_timer_$nodeId";
    await prefs.remove(key);
  }
}

extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
