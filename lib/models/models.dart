import 'dart:convert';

class WebPaResponse {
  final List<Parameter>? parameters;
  final int statusCode;

  WebPaResponse({this.parameters, this.statusCode = 0});

  factory WebPaResponse.fromJson(Map<String, dynamic> json) {
    return WebPaResponse(
      parameters: (json['parameters'] as List<dynamic>?)
          ?.map((e) => Parameter.fromJson(e))
          .toList(),
      statusCode: json['statusCode'] ?? 0,
    );
  }
}

class Parameter {
  final String name;
  final dynamic value; // can be string or array
  final int dataType;

  Parameter({required this.name, this.value, required this.dataType});

  factory Parameter.fromJson(Map<String, dynamic> json) {
    return Parameter(
      name: json['name'] ?? '',
      value: json['value'],
      dataType: json['dataType'] ?? 0,
    );
  }

  String getStringValue() {
    if (value == null) return "N/A";
    if (value is String) return value;
    return value.toString();
  }
  
  // Helper to simulate asParameterList if value is a list of parameters
  List<Parameter> asParameterList() {
    if (value is List) {
      return (value as List).map((e) => Parameter.fromJson(e)).toList();
    }
    return [];
  }
}

class WebPaRequest {
  final List<Parameter> parameters;

  WebPaRequest({required this.parameters});

  Map<String, dynamic> toJson() {
    return {
      'parameters': parameters.map((e) => e.toJson()).toList(),
    };
  }
}

extension ParameterToJson on Parameter {
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'dataType': dataType,
    };
  }
}

class ConnectedDevice {
  final String id;
  final String macAddress;
  final String ipAddress;
  final String signalStrength;
  final String downloadRate;
  final String uploadRate;
  final String hostname;
  final String connectionType;

  ConnectedDevice({
    required this.id,
    required this.macAddress,
    this.ipAddress = "",
    this.signalStrength = "",
    this.downloadRate = "",
    this.uploadRate = "",
    this.hostname = "",
    this.connectionType = "WiFi 2.4GHz",
  });
}

class RouterInfo {
  final String softwareVersion;
  final String uptime;
  final String serialNumber;
  final String modelName;
  final String wanIpAddress;
  final String deviceMac;

  RouterInfo({
    this.softwareVersion = "",
    this.uptime = "",
    this.serialNumber = "",
    this.modelName = "",
    this.wanIpAddress = "",
    this.deviceMac = "mac:0201008DA84A",
  });
}

class SmartDevice {
  final String nodeId;
  final bool isOn;
  final String label;
  /// Device class from API: e.g. "light", "plug", "thermostat", "doorlock".
  final String deviceClass;
  final int hue;
  final int brightness;
  final int saturation;

  SmartDevice({
    required this.nodeId,
    this.isOn = true,
    this.label = "Unknown Device",
    this.deviceClass = "unknown",
    this.hue = 0,
    this.brightness = 100,
    this.saturation = 100,
  });

  SmartDevice copyWith({
    String? nodeId,
    bool? isOn,
    String? label,
    String? deviceClass,
    int? hue,
    int? brightness,
    int? saturation,
  }) {
    return SmartDevice(
      nodeId: nodeId ?? this.nodeId,
      isOn: isOn ?? this.isOn,
      label: label ?? this.label,
      deviceClass: deviceClass ?? this.deviceClass,
      hue: hue ?? this.hue,
      brightness: brightness ?? this.brightness,
      saturation: saturation ?? this.saturation,
    );
  }
}

class SetParameterRequest {
  final List<SetParameter> parameters;

  SetParameterRequest({required this.parameters});

  Map<String, dynamic> toJson() {
    return {
      'parameters': parameters.map((e) => e.toJson()).toList(),
    };
  }
}

class SetParameter {
  final String name;
  final String? value;
  final int dataType;

  SetParameter({
    required this.name,
    this.value,
    this.dataType = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'dataType': dataType,
    };
  }
}

/// XConf SWU STB response for firmware upgrade.
class XConfFirmwareInfo {
  final String firmwareDownloadProtocol;
  final String firmwareFilename;
  final String firmwareLocation;
  final String info;

  XConfFirmwareInfo({
    this.firmwareDownloadProtocol = '',
    this.firmwareFilename = '',
    this.firmwareLocation = '',
    this.info = '',
  });

  factory XConfFirmwareInfo.fromJson(Map<String, dynamic> json) {
    return XConfFirmwareInfo(
      firmwareDownloadProtocol: (json['firmwareDownloadProtocol'] ?? '').toString(),
      firmwareFilename: (json['firmwareFilename'] ?? '').toString(),
      firmwareLocation: (json['firmwareLocation'] ?? '').toString(),
      info: (json['info'] ?? '').toString(),
    );
  }
}

/// Thermostat state from printDevice response (Device.Barton.temp1).
/// coolSetpoint/heatSetpoint in Celsius; systemMode: auto, heat, cool, off, emergencyHeat, fanOnly.
class ThermostatState {
  static const double heatSetpointMinC = 7.0;
  static const double heatSetpointMaxC = 30.0;
  static const double coolSetpointMinC = 16.0;
  static const double coolSetpointMaxC = 32.0;
  static const List<String> systemModes = [
    'auto', 'cool', 'off', 'emergencyHeat', 'fanOnly',
  ];
  final double heatSetpoint;
  final double coolSetpoint;
  final String label;
  final double localTemperature;
  final String systemMode;

  ThermostatState({
    this.heatSetpoint = 20.0,
    this.coolSetpoint = 24.0,
    this.label = 'Thermostat',
    this.localTemperature = 0.0,
    this.systemMode = 'off',
  });

  ThermostatState copyWith({
    double? heatSetpoint,
    double? coolSetpoint,
    String? label,
    double? localTemperature,
    String? systemMode,
  }) {
    return ThermostatState(
      heatSetpoint: heatSetpoint ?? this.heatSetpoint,
      coolSetpoint: coolSetpoint ?? this.coolSetpoint,
      label: label ?? this.label,
      localTemperature: localTemperature ?? this.localTemperature,
      systemMode: systemMode ?? this.systemMode,
    );
  }

  /// Parse printDevice response text (from WebPA GET Device.Barton.temp1 after sending printDevice).
  /// Expects lines like: /nodeId/ep/1/r/coolSetpoint = 24.00
  static ThermostatState? parsePrintDeviceResponse(String raw, [String? nodeId]) {
    if (raw.isEmpty) return null;
    double? heatSetpoint;
    double? coolSetpoint;
    String? label;
    double? localTemperature;
    String? systemMode;

    final lines = raw.split('\n');
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // Match /nodeId/ep/1/r/name = value or Endpoint 1 block
      final eqIdx = trimmed.indexOf('=');
      if (eqIdx <= 0) continue;
      final left = trimmed.substring(0, eqIdx).trim();
      final value = trimmed.substring(eqIdx + 1).trim();
      final leftKey = left.contains('/') ? left.substring(left.lastIndexOf('/') + 1) : left;
      if (leftKey == 'heatSetpoint') {
        heatSetpoint = double.tryParse(value);
      } else if (leftKey == 'coolSetpoint') {
        coolSetpoint = double.tryParse(value);
      } else if (leftKey == 'label') {
        label = value;
      } else if (leftKey == 'localTemperature') {
        localTemperature = double.tryParse(value);
      } else if (leftKey == 'systemMode') {
        systemMode = value;
      }
    }

    return ThermostatState(
      heatSetpoint: heatSetpoint ?? 20.0,
      coolSetpoint: coolSetpoint ?? 24.0,
      label: label ?? 'Thermostat',
      localTemperature: localTemperature ?? 0.0,
      systemMode: systemMode ?? 'off',
    );
  }
}

extension XConfFirmwareInfoDisplay on XConfFirmwareInfo {
  /// Display name: filename without .bin.wic.bz2 suffix.
  String get displayFilename {
    const suffix = '.bin.wic.bz2';
    if (firmwareFilename.endsWith(suffix)) {
      return firmwareFilename.substring(0, firmwareFilename.length - suffix.length);
    }
    return firmwareFilename;
  }
}
