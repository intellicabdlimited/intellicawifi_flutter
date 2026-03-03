/// A single sanity test section (one "Running Sanity Test: ..." block).
class SanityTestSection {
  final String name;
  final bool passed;
  final List<String> details;

  const SanityTestSection({
    required this.name,
    required this.passed,
    this.details = const [],
  });
}

/// Parsed result from a sanity test log (Device.Bananapi.temp1).
class SanityTestResult {
  final int totalPassed;
  final int totalFailed;
  final List<String> passedTestNames;
  final List<String> failedTestNames;
  final List<SanityTestSection> sections;
  final String rawLog;

  const SanityTestResult({
    this.totalPassed = 0,
    this.totalFailed = 0,
    this.passedTestNames = const [],
    this.failedTestNames = const [],
    this.sections = const [],
    required this.rawLog,
  });

  int get total => totalPassed + totalFailed;
  bool get allPassed => totalFailed == 0;
}

/// Extracts summary and test sections from sanity test CLI log text.
SanityTestResult parseSanityTestLog(String rawLog) {
  int totalPassed = 0;
  int totalFailed = 0;
  final passedTestNames = <String>[];
  final failedTestNames = <String>[];
  final sections = <SanityTestSection>[];

  // Total Sanity Tests Passed : N / Total Sanity Tests Failed : N
  final passedMatch = RegExp(r'Total Sanity Tests Passed\s*:\s*(\d+)', caseSensitive: false).firstMatch(rawLog);
  if (passedMatch != null) totalPassed = int.tryParse(passedMatch.group(1) ?? '') ?? 0;
  final failedMatch = RegExp(r'Total Sanity Tests Failed\s*:\s*(\d+)', caseSensitive: false).firstMatch(rawLog);
  if (failedMatch != null) totalFailed = int.tryParse(failedMatch.group(1) ?? '') ?? 0;

  // ✅ Passed Tests: ... "   → name"
  final passedSectionMatch = RegExp(r'✅ Passed Tests:\s*\n((?:\s*→\s*.+\n?)*)', caseSensitive: false).firstMatch(rawLog);
  if (passedSectionMatch != null) {
    final block = passedSectionMatch.group(1) ?? '';
    for (final line in block.split('\n')) {
      final m = RegExp(r'\s*→\s*(.+)').firstMatch(line);
      if (m != null) {
        final name = m.group(1)?.trim() ?? '';
        if (name.isNotEmpty) passedTestNames.add(name);
      }
    }
  }

  // ❌ Failed Tests: ... "   → name"
  final failedSectionMatch = RegExp(r'❌ Failed Tests:\s*\n((?:\s*→\s*.+\n?)*)', caseSensitive: false).firstMatch(rawLog);
  if (failedSectionMatch != null) {
    final block = failedSectionMatch.group(1) ?? '';
    for (final line in block.split('\n')) {
      final m = RegExp(r'\s*→\s*(.+)').firstMatch(line);
      if (m != null) {
        final name = m.group(1)?.trim() ?? '';
        if (name.isNotEmpty) failedTestNames.add(name);
      }
    }
  }

  // Individual test sections: find "Running Sanity Test: NAME" then next "✅ [PASSED]..." or "❌ [FAILED]..." and text between
  final runHeaders = RegExp(r'Running Sanity Test:\s*(.+)\s*$', multiLine: true).allMatches(rawLog);
  final resultLines = RegExp(r'(✅|❌) \[(PASSED|FAILED)\] Sanity Test:\s*(.+)\s*$', multiLine: true).allMatches(rawLog);

  final runList = runHeaders.map((m) => MapEntry(m.start, m.group(1)?.trim() ?? '')).toList();
  final resultList = resultLines
      .map((m) => MapEntry(m.start, _SanityResult(m.group(1) == '✅', m.group(3)?.trim() ?? '')))
      .toList();

  for (var i = 0; i < runList.length && i < resultList.length; i++) {
    final name = runList[i].value;
    final res = resultList[i].value;
    final runStart = runList[i].key;
    final resultStart = resultList[i].key;
    final detailBlock = rawLog.substring(runStart, resultStart);
    final lines = detailBlock
        .split('\n')
        .map((l) => l.trim())
        .where((s) => s.isNotEmpty)
        .where((s) => !s.startsWith('Running Sanity Test:') && !s.startsWith('---'))
        .toList();
    sections.add(SanityTestSection(name: name, passed: res.passed, details: lines));
  }

  return SanityTestResult(
    totalPassed: totalPassed,
    totalFailed: totalFailed,
    passedTestNames: passedTestNames,
    failedTestNames: failedTestNames,
    sections: sections,
    rawLog: rawLog,
  );
}

class _SanityResult {
  final bool passed;
  final String name;
  _SanityResult(this.passed, this.name);
}
