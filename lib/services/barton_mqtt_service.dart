import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

enum MqttConnectionStatus {
  connecting,
  connected,
  disconnected,
  error,
}

class BartonResourceUpdate {
  final String deviceUuid;
  final String endpointId;
  final String resourceId;
  final String value;
  final String uri;
  final String type;
  final int ts;

  BartonResourceUpdate({
    required this.deviceUuid,
    required this.endpointId,
    required this.resourceId,
    required this.value,
    required this.uri,
    required this.type,
    required this.ts,
  });

  static BartonResourceUpdate? tryParse(String payload) {
    final trimmed = payload.trim();
    if (!(trimmed.startsWith('{') && trimmed.endsWith('}'))) return null;
    try {
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      return BartonResourceUpdate(
        deviceUuid: (json['deviceUuid'] ?? '').toString(),
        endpointId: (json['endpointId'] ?? '').toString(),
        resourceId: (json['resourceId'] ?? '').toString(),
        value: (json['value'] ?? '').toString(),
        uri: (json['uri'] ?? '').toString(),
        type: (json['type'] ?? '').toString(),
        ts: int.tryParse((json['ts'] ?? '').toString()) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  bool? get boolValue {
    final v = value.trim().toLowerCase();
    if (v == 'true') return true;
    if (v == 'false') return false;
    return null;
  }
}

class BartonMqttService {
  static const String topicResourceUpdated = 'barton/resource-updated';

  final String host;
  final int port;

  final StreamController<BartonResourceUpdate> _updatesController =
      StreamController<BartonResourceUpdate>.broadcast();
  Stream<BartonResourceUpdate> get updates => _updatesController.stream;

  final StreamController<MqttConnectionStatus> _statusController =
      StreamController<MqttConnectionStatus>.broadcast();
  Stream<MqttConnectionStatus> get statusStream => _statusController.stream;

  MqttConnectionStatus _status = MqttConnectionStatus.disconnected;
  MqttConnectionStatus get status => _status;

  MqttServerClient? _client;

  BartonMqttService({
    required this.host,
    required this.port,
  });

  Future<void> connectAndSubscribe({required String clientId}) async {
    if (_client != null &&
        (_status == MqttConnectionStatus.connected ||
            _status == MqttConnectionStatus.connecting)) {
      return;
    }

    _setStatus(MqttConnectionStatus.connecting);
    final client = MqttServerClient.withPort(host, clientId, port);
    _client = client;

    client.keepAlivePeriod = 20;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.logging(on: false);
    client.onConnected = () => _setStatus(MqttConnectionStatus.connected);
    client.onDisconnected = () => _setStatus(MqttConnectionStatus.disconnected);
    client.onAutoReconnect = () => _setStatus(MqttConnectionStatus.connecting);
    client.onAutoReconnected = () => _setStatus(MqttConnectionStatus.connected);

    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    try {
      await client.connect();
    } catch (_) {
      _setStatus(MqttConnectionStatus.error);
      try {
        client.disconnect();
      } catch (_) {}
      rethrow;
    }

    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      _setStatus(MqttConnectionStatus.error);
      throw StateError('MQTT connection failed: ${client.connectionStatus}');
    }

    client.subscribe(topicResourceUpdated, MqttQos.atLeastOnce);

    client.updates?.listen((events) {
      for (final event in events) {
        final rec = event.payload as MqttPublishMessage;
        final payload =
            MqttPublishPayload.bytesToStringAsString(rec.payload.message);
        final update = BartonResourceUpdate.tryParse(payload);
        if (update != null) {
          _updatesController.add(update);
        }
      }
    });
  }

  Future<void> disconnect() async {
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;
    _setStatus(MqttConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _updatesController.close();
    _statusController.close();
  }

  void _setStatus(MqttConnectionStatus next) {
    _status = next;
    _statusController.add(next);
  }
}

