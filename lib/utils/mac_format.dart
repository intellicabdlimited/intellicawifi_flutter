/// Formats MAC address from stored form (e.g. "mac:0201008E5E97" or "0201008E5E97")
/// to colon-separated form for XConf API: "02:01:00:8E:5E:97".
String formatMacWithColons(String mac) {
  String raw = mac.replaceFirst(RegExp(r'^mac:'), '').replaceAll(':', '');
  if (raw.length != 12) return mac;
  final buffer = StringBuffer();
  for (int i = 0; i < raw.length; i += 2) {
    if (i > 0) buffer.write(':');
    buffer.write(raw.substring(i, i + 2));
  }
  return buffer.toString();
}
