/// Parsed result from a speed test log (Device.Bananapi.temp2).
class SpeedTestResult {
  final String? timestamp;
  final String? testingFrom;  // e.g. "D Taj Online (103.189.106.199)"
  final String? serverName;   // e.g. "Star Planet Technovision Pvt Ltd (Rourkela)"
  final String? distanceKm;
  final String? pingMs;
  final String? downloadMbps;
  final String? uploadMbps;
  final List<String> warnings;
  final String rawLog;

  const SpeedTestResult({
    this.timestamp,
    this.testingFrom,
    this.serverName,
    this.distanceKm,
    this.pingMs,
    this.downloadMbps,
    this.uploadMbps,
    this.warnings = const [],
    required this.rawLog,
  });

  bool get hasParsedData =>
      timestamp != null ||
      testingFrom != null ||
      serverName != null ||
      downloadMbps != null ||
      uploadMbps != null;
}

/// Extracts key fields from speedtest CLI log text.
SpeedTestResult parseSpeedTestLog(String rawLog) {
  String? timestamp;
  String? testingFrom;
  String? serverName;
  String? distanceKm;
  String? pingMs;
  String? downloadMbps;
  String? uploadMbps;
  // Ignore /usr/bin/env: python: No such file or directory — not shown as warning.
  final warnings = <String>[];

  // Timestamp: [2026-03-03 03:44:53]
  final tsMatch = RegExp(r'\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]').firstMatch(rawLog);
  if (tsMatch != null) timestamp = tsMatch.group(1);

  // Testing from D Taj Online (103.189.106.199)...
  final fromMatch = RegExp(r'Testing from (.+?)(?:\.\.\.)?\s*$', multiLine: true).firstMatch(rawLog);
  if (fromMatch != null) testingFrom = fromMatch.group(1)?.trim();

  // Hosted by Star Planet Technovision Pvt Ltd (Rourkela) [448.60 km]: 56.069 ms
  final serverMatch = RegExp(
    r'Hosted by (.+?) \[([\d.]+) km\]: ([\d.]+) ms',
    caseSensitive: false,
  ).firstMatch(rawLog);
  if (serverMatch != null) {
    serverName = serverMatch.group(1)?.trim();
    distanceKm = serverMatch.group(2);
    pingMs = serverMatch.group(3);
  }

  // Download: 85.67 Mbit/s
  final dlMatch = RegExp(r'Download:\s*([\d.]+)\s*Mbit/s', caseSensitive: false).firstMatch(rawLog);
  if (dlMatch != null) downloadMbps = dlMatch.group(1);

  // Upload: 91.47 Mbit/s or Upload: 91.47 (truncated)
  final ulMatch = RegExp(r'Upload:\s*([\d.]+)(?:\s*Mbit/s)?', caseSensitive: false).firstMatch(rawLog);
  if (ulMatch != null) uploadMbps = ulMatch.group(1);

  return SpeedTestResult(
    timestamp: timestamp,
    testingFrom: testingFrom,
    serverName: serverName,
    distanceKm: distanceKm,
    pingMs: pingMs,
    downloadMbps: downloadMbps,
    uploadMbps: uploadMbps,
    warnings: warnings,
    rawLog: rawLog,
  );
}
