import '../api/api_service.dart';
import '../models/models.dart';
import '../utils/router_mac_manager.dart';
import '../utils/mac_format.dart';

class FirmwareRepository {
  final ApiService _api = ApiService();

  Future<XConfFirmwareInfo> getXconfFirmwareInfo() async {
    final rawMac = await RouterMacManager.getMac();
    if (rawMac.isEmpty || rawMac == "mac:") {
      throw Exception("No MAC address configured");
    }
    final macWithColons = formatMacWithColons(rawMac);
    return _api.getXconfFirmwareInfo(macWithColons);
  }

  /// Triggers firmware upgrade by calling the four WebPA config PATCH APIs in sequence.
  /// Returns a list of (parameterName, success) for each step.
  Future<List<({String name, bool success})>> triggerFirmwareUpgrade({
    required String protocol,
    required String location,
    required String filename,
  }) async {
    final deviceMac = await RouterMacManager.getMac();
    if (deviceMac.isEmpty || deviceMac == "mac:") {
      throw Exception("No MAC address configured");
    }

    final protocolUpper = protocol.toUpperCase();
    final downloadUrl = "${protocol.toLowerCase()}://$location:69";

    final steps = <({String name, bool success})>[];

    // 1. FirmwareDownloadProtocol
    try {
      final resp = await _api.setDeviceParameter(
        deviceMac,
        SetParameterRequest(
          parameters: [
            SetParameter(
              name: "Device.DeviceInfo.X_RDKCENTRAL-COM_FirmwareDownloadProtocol",
              value: protocolUpper,
              dataType: 0,
            ),
          ],
        ),
      );
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      steps.add((name: "FirmwareDownloadProtocol", success: ok));
      if (!ok) throw Exception("FirmwareDownloadProtocol failed: ${resp.statusCode}");
    } catch (e) {
      steps.add((name: "FirmwareDownloadProtocol", success: false));
      rethrow;
    }

    // 2. FirmwareDownloadURL
    try {
      final resp = await _api.setDeviceParameter(
        deviceMac,
        SetParameterRequest(
          parameters: [
            SetParameter(
              name: "Device.DeviceInfo.X_RDKCENTRAL-COM_FirmwareDownloadURL",
              value: downloadUrl,
              dataType: 0,
            ),
          ],
        ),
      );
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      steps.add((name: "FirmwareDownloadURL", success: ok));
      if (!ok) throw Exception("FirmwareDownloadURL failed: ${resp.statusCode}");
    } catch (e) {
      steps.add((name: "FirmwareDownloadURL", success: false));
      rethrow;
    }

    // 3. FirmwareToDownload
    try {
      final resp = await _api.setDeviceParameter(
        deviceMac,
        SetParameterRequest(
          parameters: [
            SetParameter(
              name: "Device.DeviceInfo.X_RDKCENTRAL-COM_FirmwareToDownload",
              value: filename,
              dataType: 0,
            ),
          ],
        ),
      );
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      steps.add((name: "FirmwareToDownload", success: ok));
      if (!ok) throw Exception("FirmwareToDownload failed: ${resp.statusCode}");
    } catch (e) {
      steps.add((name: "FirmwareToDownload", success: false));
      rethrow;
    }

    // 4. FirmwareDownloadAndFactoryReset
    try {
      final resp = await _api.setDeviceParameter(
        deviceMac,
        SetParameterRequest(
          parameters: [
            SetParameter(
              name: "Device.DeviceInfo.X_RDKCENTRAL-COM_FirmwareDownloadAndFactoryReset",
              value: "1",
              dataType: 1,
            ),
          ],
        ),
      );
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      steps.add((name: "FirmwareDownloadAndFactoryReset", success: ok));
      if (!ok) throw Exception("FirmwareDownloadAndFactoryReset failed: ${resp.statusCode}");
    } catch (e) {
      steps.add((name: "FirmwareDownloadAndFactoryReset", success: false));
      rethrow;
    }

    return steps;
  }
}
