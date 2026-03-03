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
  /// Device class from API: "light" or "plug"
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

  /// Display name: filename without .bin.wic.bz2 suffix.
  String get displayFilename {
    const suffix = '.bin.wic.bz2';
    if (firmwareFilename.endsWith(suffix)) {
      return firmwareFilename.substring(0, firmwareFilename.length - suffix.length);
    }
    return firmwareFilename;
  }
}
