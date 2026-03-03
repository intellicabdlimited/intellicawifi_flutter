import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/models.dart';

class ApiService {
  static const String _baseUrl = "https://webpa.rdkcentral.com:9003";
  static const String _authHeader = "Basic d3B1c2VyOndlYnBhQDEyMzQ1Njc4OTAK";
  /// XConf SWU base URL (no trailing slash). Use HTTP for local/device server.
  static const String xconfBaseUrl = "http://192.168.1.208:19092";

  // Create an IOClient that ignores bad certificates (unsafe, matching original logic)
  static http.Client _createHttpClient() {
    final ioc = HttpClient();
    ioc.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    ioc.connectionTimeout = const Duration(seconds: 30);
    return IOClient(ioc);
  }

  static final http.Client _client = _createHttpClient();

  Future<WebPaResponse> getDeviceParameter(String deviceMac, String parameterName) async {
    final url = Uri.parse("$_baseUrl/api/v2/device/$deviceMac/config?names=$parameterName");
    
    print("------------------------------------------------------------------");
    print("API Request: GET $url");
    print("Headers: {Authorization: $_authHeader}");
    print("------------------------------------------------------------------");

    try {
      final response = await _client.get(
        url,
        headers: {
          'Authorization': _authHeader,
        },
      );

      print("------------------------------------------------------------------");
      print("API Response: ${response.statusCode}");
      print("Response Body: ${response.body}");
      print("------------------------------------------------------------------");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonMap = jsonDecode(response.body);
        return WebPaResponse.fromJson(jsonMap);
      } else {
        throw HttpException("Failed to get parameter: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      print("API Error: $e");
      rethrow;
    }
  }

  Future<WebPaResponse> setDeviceParameter(String deviceMac, SetParameterRequest body) async {
    final url = Uri.parse("$_baseUrl/api/v2/device/$deviceMac/config");
    final reqBody = jsonEncode(body.toJson());
    
    print("------------------------------------------------------------------");
    print("API Request: PATCH $url");
    print("Headers: {Authorization: $_authHeader, Content-Type: application/json}");
    print("Request Body: $reqBody");
    print("------------------------------------------------------------------");

    try {
      final response = await _client.patch(
        url,
        headers: {
          'Authorization': _authHeader,
          'Content-Type': 'application/json',
        },
        body: reqBody,
      );
      
      print("------------------------------------------------------------------");
      print("API Response: ${response.statusCode}");
      print("Response Body: ${response.body}");
      print("------------------------------------------------------------------");

      // Original logic handles 520 as success in SmartHomeRepository?
      // We will let the repository handle that specific logic or handle general success here.
      // But we return the response object or throw.
      
      // Note: Repository needs to check status code 520, so we might need to return the status code in WebPaResponse even if it fails?
      // The WebPaResponse model has a statusCode field, let's use it.
      
      Map<String, dynamic> jsonMap = {};
      try {
        if (response.body.isNotEmpty) {
          jsonMap = jsonDecode(response.body);
        }
      } catch (_) {}
      
      jsonMap['statusCode'] = response.statusCode;
      
      return WebPaResponse.fromJson(jsonMap);
      
    } catch (e) {
      print("API Error: $e");
      rethrow;
    }
  }

  Future<WebPaResponse> rebootDevice(String deviceMac, WebPaRequest body) async {
    final url = Uri.parse("$_baseUrl/api/v2/device/$deviceMac/config");
    final reqBody = jsonEncode(body.toJson());

    print("------------------------------------------------------------------");
    print("API Request: PATCH $url");
    print("Headers: {Authorization: $_authHeader, Content-Type: application/json}");
    print("Request Body: $reqBody");
    print("------------------------------------------------------------------");

    try {
      final response = await _client.patch(
        url,
        headers: {
          'Authorization': _authHeader,
          'Content-Type': 'application/json',
        },
        body: reqBody,
      );

      print("------------------------------------------------------------------");
      print("API Response: ${response.statusCode}");
      print("Response Body: ${response.body}");
      print("------------------------------------------------------------------");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonMap = jsonDecode(response.body);
        return WebPaResponse.fromJson(jsonMap);
      } else {
         throw HttpException("Failed to reboot: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      print("API Error: $e");
      rethrow;
    }
  }

  /// Fetches firmware metadata from XConf SWU STB endpoint.
  /// [macWithColons] should be in format "02:01:00:8E:5E:97".
  Future<XConfFirmwareInfo> getXconfFirmwareInfo(String macWithColons) async {
    final url = Uri.parse("$xconfBaseUrl/xconf/swu/stb?eStbMac=$macWithColons");
    print("------------------------------------------------------------------");
    print("XConf Request: GET $url");
    print("------------------------------------------------------------------");
    try {
      final response = await _client.get(url);
      print("------------------------------------------------------------------");
      print("XConf Response: ${response.statusCode}");
      print("Response Body: ${response.body}");
      print("------------------------------------------------------------------");
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        return XConfFirmwareInfo.fromJson(jsonMap);
      } else {
        throw HttpException("XConf failed: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      print("XConf API Error: $e");
      rethrow;
    }
  }
}

