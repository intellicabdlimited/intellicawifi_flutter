import '../api/api_service.dart';
import '../models/models.dart';
import '../utils/router_mac_manager.dart';

/// Runs a troubleshooting test: PATCH to trigger the test, then GET to fetch the result value.
class TroubleshootingRepository {
  final ApiService _api = ApiService();

  /// [parameterName] e.g. Device.Bananapi.temp1 (sanity), temp2 (speed), temp3 (traceroute).
  /// Returns the value string from the GET response, or throws on error.
  Future<String> runTest(String parameterName) async {
    final deviceMac = await RouterMacManager.getMac();
    if (deviceMac.isEmpty || deviceMac == "mac:") {
      throw Exception("No MAC address configured");
    }

    // 1. PATCH to trigger the test
    final setResp = await _api.setDeviceParameter(
      deviceMac,
      SetParameterRequest(
        parameters: [
          SetParameter(
            name: parameterName,
            value: "true",
            dataType: 0,
          ),
        ],
      ),
    );
    if (setResp.statusCode < 200 || setResp.statusCode >= 300) {
      throw Exception("Failed to start test: ${setResp.statusCode}");
    }

    // 2. Delay so the device can produce the result (varies by test type)
    final delaySeconds = _delaySecondsForTest(parameterName);
    await Future<void>.delayed(Duration(seconds: delaySeconds));

    // 3. GET to retrieve the result value
    final getResp = await _api.getDeviceParameter(deviceMac, parameterName);
    if (getResp.statusCode < 200 || getResp.statusCode >= 300) {
      throw Exception("Failed to get result: ${getResp.statusCode}");
    }

    final param = getResp.parameters?.isNotEmpty == true
        ? getResp.parameters!.first
        : null;
    if (param == null) {
      throw Exception("No result data in response");
    }
    return param.getStringValue();
  }

  /// Returns the number of seconds to wait after PATCH before GET, by test parameter.
  static int _delaySecondsForTest(String parameterName) {
    switch (parameterName) {
      case 'Device.Bananapi.temp1':
        return 20; // sanity test
      case 'Device.Bananapi.temp2':
        return 15; // speed test
      case 'Device.Bananapi.temp3':
        return 15; // traceroute
      default:
        return 15;
    }
  }
}
