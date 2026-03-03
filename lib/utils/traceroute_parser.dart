/// A single hop in a traceroute result.
class TracerouteHop {
  final int hopNumber;
  final String display;  // e.g. "_gateway (192.168.1.1)" or "*"
  final double? timeMs;   // null if timeout (*)

  const TracerouteHop({
    required this.hopNumber,
    required this.display,
    this.timeMs,
  });

  bool get isTimeout => timeMs == null;
}

/// Parsed result from a traceroute log (Device.Bananapi.temp3).
class TracerouteResult {
  final String? timestamp;
  final String? target;      // e.g. "8.8.8.8"
  final String? targetName;  // e.g. "dns.google" if present in last hop
  final int? maxHops;
  final int? packetSize;
  final List<TracerouteHop> hops;
  final String rawLog;

  const TracerouteResult({
    this.timestamp,
    this.target,
    this.targetName,
    this.maxHops,
    this.packetSize,
    this.hops = const [],
    required this.rawLog,
  });

  bool get hasParsedData =>
      timestamp != null || target != null || hops.isNotEmpty;
}

/// Extracts key fields from traceroute CLI log text.
TracerouteResult parseTracerouteLog(String rawLog) {
  String? timestamp;
  String? target;
  int? maxHops;
  int? packetSize;
  final hops = <TracerouteHop>[];

  // Timestamp: [2026-03-03 05:19:23]
  final tsMatch = RegExp(r'\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]').firstMatch(rawLog);
  if (tsMatch != null) timestamp = tsMatch.group(1);

  // TRACEROUTE 8.8.8.8 or traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 46 byte packets
  final targetMatch = RegExp(r'TRACEROUTE\s+([\d.]+)|traceroute to ([\d.]+)', caseSensitive: false).firstMatch(rawLog);
  if (targetMatch != null) {
    target = targetMatch.group(1) ?? targetMatch.group(2);
  }
  final optsMatch = RegExp(r'(\d+)\s*hops max', caseSensitive: false).firstMatch(rawLog);
  if (optsMatch != null) maxHops = int.tryParse(optsMatch.group(1) ?? '');
  final bytesMatch = RegExp(r'(\d+)\s*byte packets', caseSensitive: false).firstMatch(rawLog);
  if (bytesMatch != null) packetSize = int.tryParse(bytesMatch.group(1) ?? '');

  // Hop lines: " 1  _gateway (192.168.1.1)  0.527 ms" or " 4  *"
  final hopLineRegex = RegExp(r'^\s*(\d+)\s+(.+)$', multiLine: true);
  for (final match in hopLineRegex.allMatches(rawLog)) {
    final hopNum = int.tryParse(match.group(1) ?? '') ?? 0;
    var part = match.group(2)?.trim() ?? '';
    if (part.isEmpty) continue;
    if (part == '*') {
      hops.add(TracerouteHop(hopNumber: hopNum, display: '*'));
      continue;
    }
    // "host (ip)  0.527 ms" or "host (ip)  30.672 ms."
    final timeMatch = RegExp(r'([\d.]+)\s*ms\.?\s*$').firstMatch(part);
    double? timeMs;
    String display = part;
    if (timeMatch != null) {
      timeMs = double.tryParse(timeMatch.group(1) ?? '');
      display = part.substring(0, timeMatch.start).trim();
    }
    hops.add(TracerouteHop(hopNumber: hopNum, display: display, timeMs: timeMs));
  }

  return TracerouteResult(
    timestamp: timestamp,
    target: target,
    maxHops: maxHops,
    packetSize: packetSize,
    hops: hops,
    rawLog: rawLog,
  );
}
