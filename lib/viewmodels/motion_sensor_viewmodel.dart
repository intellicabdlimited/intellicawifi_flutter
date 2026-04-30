import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../repositories/smart_home_repository.dart';

enum MotionMqttStatus { connecting, connected, disconnected }

class MotionSensorState {
  final bool isOn;
  final String illuminance;
  final MotionMqttStatus connectionStatus;
  final String? message;

  const MotionSensorState({
    this.isOn = false,
    this.illuminance = '--',
    this.connectionStatus = MotionMqttStatus.disconnected,
    this.message,
  });

  MotionSensorState copyWith({
    bool? isOn,
    String? illuminance,
    MotionMqttStatus? connectionStatus,
    String? message,
  }) {
    return MotionSensorState(
      isOn: isOn ?? this.isOn,
      illuminance: illuminance ?? this.illuminance,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      message: message,
    );
  }
}

class MotionSensorViewModel extends ChangeNotifier {
  MotionSensorViewModel({required this.nodeId});

  final String nodeId;
  final SmartHomeRepository _repository = SmartHomeRepository();
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSub;

  static const String _topic = 'barton/resource-updated';
  static const int _port = 1883;

  MotionSensorState _state = const MotionSensorState();
  MotionSensorState get state => _state;

  Future<void> connectAndListen() async {
    _state = _state.copyWith(
      connectionStatus: MotionMqttStatus.connecting,
      message: null,
    );
    notifyListeners();

    final host = await _repository.getBartonCoreIpAddress();
    if (host == null || host.isEmpty) {
      _state = _state.copyWith(
        connectionStatus: MotionMqttStatus.disconnected,
        message: 'Banana Pi/Barton device IP not found.',
      );
      notifyListeners();
      return;
    }

    final clientId = 'intellica_motion_${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient(host, clientId)
      ..port = _port
      ..keepAlivePeriod = 20
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..logging(on: false)
      ..onConnected = _onConnected
      ..onDisconnected = _onDisconnected
      ..onAutoReconnected = _onAutoReconnected;

    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    try {
      _client = client;
      await client.connect();
      _listenToUpdates(client);
    } catch (e) {
      _state = _state.copyWith(
        connectionStatus: MotionMqttStatus.disconnected,
        message: 'MQTT connection failed: $e',
      );
      notifyListeners();
      disconnect();
    }
  }

  void _listenToUpdates(MqttServerClient client) {
    client.subscribe(_topic, MqttQos.atLeastOnce);
    _updatesSub?.cancel();
    _updatesSub = client.updates?.listen((events) {
      for (final event in events) {
        final msg = event.payload;
        if (msg is! MqttPublishMessage) continue;
        final payload = MqttPublishPayload.bytesToStringAsString(
          msg.payload.message,
        );
        _handlePayload(payload);
      }
    });
  }

  void _handlePayload(String payload) {
    try {
      var raw = payload.trim();
      if (raw.startsWith('$_topic ')) {
        raw = raw.substring(_topic.length + 1).trim();
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      final payloadNodeId = (decoded['deviceUuid'] ?? '').toString();
      if (payloadNodeId != nodeId) return;

      final resourceId = (decoded['resourceId'] ?? '').toString();
      final value = (decoded['value'] ?? '').toString();

      if (resourceId == 'matterOccupancyOccupied') {
        final isOn = value.toLowerCase() == 'true';
        _state = _state.copyWith(isOn: isOn);
        notifyListeners();
      } else if (resourceId == 'illuminance') {
        _state = _state.copyWith(illuminance: value);
        notifyListeners();
      }
    } catch (_) {
      // Ignore malformed payloads.
    }
  }

  void _onConnected() {
    _state = _state.copyWith(
      connectionStatus: MotionMqttStatus.connected,
      message: null,
    );
    notifyListeners();
  }

  void _onDisconnected() {
    _state = _state.copyWith(
      connectionStatus: MotionMqttStatus.disconnected,
      message: _state.message,
    );
    notifyListeners();
  }

  void _onAutoReconnected() {
    _state = _state.copyWith(
      connectionStatus: MotionMqttStatus.connected,
      message: null,
    );
    notifyListeners();
  }

  void disconnect() {
    _updatesSub?.cancel();
    _updatesSub = null;
    _client?.disconnect();
    _client = null;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
