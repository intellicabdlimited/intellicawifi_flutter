import '../api/api_service.dart';
import '../models/models.dart';
import '../utils/router_mac_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartHomeRepository {
  final ApiService _api = ApiService();
  static const String _associatedDevicesParam = "Device.WiFi.AccessPoint.10001.AssociatedDevice.";
  static const String _hostsParam = "Device.Hosts.Host.";
  static const String _wanIpParam = "Device.IP.Interface.1.IPv4Address.1.IPAddress";

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

  /// Thermostat: send printDevice via Device.Barton.temp1 (set), then get Device.Barton.temp1 to read response.
  static const String _bartonTemp1 = "Device.Barton.temp1";

  Future<String> getBartonTemp1() async {
    final deviceMac = await RouterMacManager.getMac();
    try {
      final response = await _api.getDeviceParameter(deviceMac, _bartonTemp1);
      return response.parameters?.firstOrNull?.getStringValue() ?? "";
    } catch (e) {
      return "";
    }
  }

  Future<bool> setBartonTemp1(String command) async {
    return _sendSetRequest(_bartonTemp1, command);
  }

  /// Read thermostat state: set printDevice nodeId, wait briefly, then get and parse.
  Future<ThermostatState?> getThermostatState(String nodeId) async {
    try {
      final ok = await setBartonTemp1("printDevice $nodeId");
      if (!ok) return null;
      await Future.delayed(const Duration(milliseconds: 800));
      final raw = await getBartonTemp1();
      return ThermostatState.parsePrintDeviceResponse(raw, nodeId);
    } catch (e) {
      return null;
    }
  }

  /// Write heat setpoint (Celsius, 7–30).
  Future<bool> setThermostatHeatSetpoint(String nodeId, double valueC) async {
    final v = valueC.toStringAsFixed(2);
    return setBartonTemp1("writeResource /$nodeId/ep/1/r/heatSetpoint $v");
  }

  /// Write cool setpoint (Celsius, 16–32).
  Future<bool> setThermostatCoolSetpoint(String nodeId, double valueC) async {
    final v = valueC.toStringAsFixed(2);
    return setBartonTemp1("writeResource /$nodeId/ep/1/r/coolSetpoint $v");
  }

  /// Write system mode: auto, heat, cool, off, emergencyHeat, fanOnly.
  Future<bool> setThermostatSystemMode(String nodeId, String mode) async {
    return setBartonTemp1("writeResource /$nodeId/ep/1/r/systemMode $mode");
  }

  /// Matter door lock: write label via Device.Barton.temp1 (writeResource).
  Future<bool> setDoorLockLabel(String nodeId, String label) async {
    //final escaped = label.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return setBartonTemp1("writeResource /$nodeId/ep/1/r/label '$label'");
  }

  /// Lock or unlock the door (`locked` resource).
  Future<bool> setDoorLocked(String nodeId, bool locked) async {
    return setBartonTemp1(
      "writeResource /$nodeId/ep/1/r/locked ${locked ? 'true' : 'false'}",
    );
  }

  /// Read lock state: PATCH readResource, then GET Device.Barton.temp1 and parse true/false.
  Future<bool?> getDoorLockLocked(String nodeId) async {
    try {
      final ok = await setBartonTemp1("readResource /$nodeId/ep/1/r/locked");
      if (!ok) return null;
      await Future.delayed(const Duration(milliseconds: 800));
      final raw = await getBartonTemp1();
      return _parseBoolFromBartonTemp1(raw);
    } catch (e) {
      return null;
    }
  }

  bool? _parseBoolFromBartonTemp1(String raw) {
    final match = RegExp(r'\b(true|false)\b', caseSensitive: false).firstMatch(raw);
    if (match != null) {
      return match.group(0)!.toLowerCase() == 'true';
    }
    return null;
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

      final idClassDriverRegex = RegExp(
        r'^\s*([0-9a-fA-F]+):\s*Class:\s*([^,]+?)(?:\s*,\s*Driver:\s*([^\s,]+))?\s*$',
      );
      final labelRegex = RegExp(r'Label:\s*(.*)');

      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed.startsWith("barton-core>")) continue;

        final idClassMatch = idClassDriverRegex.firstMatch(line);
        if (idClassMatch != null) {
          currentId = idClassMatch.group(1);
          final deviceClass = (idClassMatch.group(2) ?? "light").trim().toLowerCase();
          final driver = (idClassMatch.group(3) ?? "").trim();
          if (currentId != null) {
            devices.add(SmartDevice(
              nodeId: currentId,
              label: "Unknown Device",
              deviceClass: deviceClass,
              driver: driver,
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

  /// Returns Banana Pi / Barton Core IP to use as MQTT broker host.
  Future<String?> getBartonCoreIpAddress() async {
    final deviceMac = await RouterMacManager.getMac();

    // Use the same WAN IP source shown in About Router.
    try {
      final wanResponse = await _api.getDeviceParameter(deviceMac, _wanIpParam);
      final wanIp = wanResponse.parameters?.firstOrNull?.getStringValue().trim() ?? "";
      if (wanIp.isNotEmpty && wanIp != "N/A") {
        return wanIp;
      }
    } catch (_) {}

    try {
      final response = await _api.getDeviceParameter(deviceMac, _hostsParam);
      final topParams = response.parameters ?? [];
      final flatParams = topParams.expand((p) => p.asParameterList()).toList();
      final grouped = _groupParamsByIndex(flatParams, RegExp(r'Host\.(\d+)\.'));

      for (final params in grouped.values) {
        final hostName = _readParamValue(params, "HostName").toLowerCase();
        final ip = _readParamValue(params, "IPAddress");
        if (ip.isNotEmpty && (hostName.contains("barton") || hostName.contains("banana"))) {
          return ip;
        }
      }
    } catch (_) {}

    // Fallback: try AssociatedDevice list.
    try {
      final response = await _api.getDeviceParameter(deviceMac, _associatedDevicesParam);
      final topParams = response.parameters ?? [];
      final flatParams = topParams.expand((p) => p.asParameterList()).toList();
      final grouped =
          _groupParamsByIndex(flatParams, RegExp(r'AssociatedDevice\.(\d+)\.'));

      for (final params in grouped.values) {
        final hostName = _readParamValue(params, "HostName").toLowerCase();
        final ip = _readParamValue(params, "IPAddress");
        if (ip.isNotEmpty && (hostName.contains("barton") || hostName.contains("banana"))) {
          return ip;
        }
      }
    } catch (_) {}

    return null;
  }

  Map<String, List<Parameter>> _groupParamsByIndex(
    List<Parameter> params,
    RegExp indexRegex,
  ) {
    final result = <String, List<Parameter>>{};
    for (final param in params) {
      final match = indexRegex.firstMatch(param.name);
      if (match == null) continue;
      final index = match.group(1)!;
      result.putIfAbsent(index, () => []).add(param);
    }
    return result;
  }

  String _readParamValue(List<Parameter> params, String suffix) {
    return params
        .firstWhere(
          (p) => p.name.endsWith(suffix),
          orElse: () => Parameter(name: "", dataType: 0, value: null),
        )
        .getStringValue()
        .replaceAll("N/A", "")
        .trim();
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
