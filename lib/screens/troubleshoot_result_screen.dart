import 'dart:developer';

import 'package:flutter/material.dart';
import '../repositories/troubleshooting_repository.dart';
import '../theme/app_theme.dart';
import '../utils/sanity_test_parser.dart';
import '../utils/speed_test_parser.dart';
import '../utils/traceroute_parser.dart';

/// Parameter name for sanity test (Device.Bananapi.temp1) — show parsed decorative UI.
const String kSanityTestParameterName = 'Device.Bananapi.temp1';

/// Parameter name for speed test (Device.Bananapi.temp2) — show parsed decorative UI.
const String kSpeedTestParameterName = 'Device.Bananapi.temp2';

/// Parameter name for traceroute (Device.Bananapi.temp3) — show parsed decorative UI.
const String kTracerouteParameterName = 'Device.Bananapi.temp3';

class TroubleshootResultScreen extends StatefulWidget {
  final String title;
  final String parameterName;

  const TroubleshootResultScreen({
    super.key,
    required this.title,
    required this.parameterName,
  });

  @override
  State<TroubleshootResultScreen> createState() => _TroubleshootResultScreenState();
}

class _TroubleshootResultScreenState extends State<TroubleshootResultScreen> {
  final TroubleshootingRepository _repo = TroubleshootingRepository();
  bool _loading = true;
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runTest();
  }

  Future<void> _runTest() async {
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    try {
      final value = await _repo.runTest(widget.parameterName);
      if (mounted) {
        setState(() {
          _loading = false;
          _result = value;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  bool get _isParsedTest =>
      widget.parameterName == kSanityTestParameterName ||
      widget.parameterName == kSpeedTestParameterName ||
      widget.parameterName == kTracerouteParameterName;

  void _showRawLog(BuildContext context) {
    final raw = _result ?? '';
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Raw log'),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(
                raw,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (!_loading && _result != null && _isParsedTest)
            IconButton(
              icon: const Icon(Icons.article_outlined),
              onPressed: () => _showRawLog(context),
              tooltip: 'View raw log',
            ),
          if (!_loading && (_result != null || _error != null))
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _runTest,
              tooltip: 'Run again',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Running test…',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppTheme.errorColor.withOpacity(0.8),
              ),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _runTest,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final result = _result ?? '';
    //log(result);
    final isSanityTest = widget.parameterName == kSanityTestParameterName;
    final isSpeedTest = widget.parameterName == kSpeedTestParameterName;
    final isTraceroute = widget.parameterName == kTracerouteParameterName;
    if (isSanityTest && result.isNotEmpty) {
      final parsed = parseSanityTestLog(result);
      return _buildSanityTestBody(context, parsed);
    }
    if (isSpeedTest && result.isNotEmpty) {
      final parsed = parseSpeedTestLog(result);
      return _buildSpeedTestBody(context, parsed);
    }
    if (isTraceroute && result.isNotEmpty) {
      final parsed = parseTracerouteLog(result);
      return _buildTracerouteBody(context, parsed);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: SelectableText(
        result,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildSpeedTestBody(BuildContext context, SpeedTestResult parsed) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (parsed.warnings.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.errorColor.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      parsed.warnings.join('\n'),
                      style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (parsed.timestamp != null) ...[
            _InfoChip(
              icon: Icons.schedule_rounded,
              label: 'Time',
              value: parsed.timestamp!,
            ),
            const SizedBox(height: 12),
          ],
          if (parsed.testingFrom != null) ...[
            _InfoChip(
              icon: Icons.public_rounded,
              label: 'Testing from',
              value: parsed.testingFrom!,
            ),
            const SizedBox(height: 12),
          ],
          if (parsed.serverName != null || parsed.pingMs != null) ...[
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.dns_rounded, color: AppTheme.primaryColor, size: 22),
                        const SizedBox(width: 8),
                        Text('Server', style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        )),
                      ],
                    ),
                    if (parsed.serverName != null) ...[
                      const SizedBox(height: 6),
                      Text(parsed.serverName!, style: theme.textTheme.bodyMedium),
                    ],
                    if (parsed.distanceKm != null || parsed.pingMs != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          if (parsed.distanceKm != null)
                            _SmallChip(text: '${parsed.distanceKm} km'),
                          if (parsed.pingMs != null)
                            _SmallChip(text: '${parsed.pingMs} ms ping'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (parsed.downloadMbps != null || parsed.uploadMbps != null) ...[
            Row(
              children: [
                if (parsed.downloadMbps != null)
                  Expanded(
                    child: _SpeedCard(
                      icon: Icons.download_rounded,
                      label: 'Download',
                      value: parsed.downloadMbps!,
                      unit: 'Mbit/s',
                      color: Colors.green,
                    ),
                  ),
                if (parsed.downloadMbps != null && parsed.uploadMbps != null) const SizedBox(width: 12),
                if (parsed.uploadMbps != null)
                  Expanded(
                    child: _SpeedCard(
                      icon: Icons.upload_rounded,
                      label: 'Upload',
                      value: parsed.uploadMbps!,
                      unit: 'Mbit/s',
                      color: Colors.blue,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (!parsed.hasParsedData)
            SelectableText(
              parsed.rawLog,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.8), height: 1.4),
            ),
        ],
      ),
    );
  }

  Widget _buildTracerouteBody(BuildContext context, TracerouteResult parsed) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (parsed.timestamp != null) ...[
            _InfoChip(
              icon: Icons.schedule_rounded,
              label: 'Time',
              value: parsed.timestamp!,
            ),
            const SizedBox(height: 12),
          ],
          if (parsed.target != null) ...[
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.gps_fixed_rounded, color: AppTheme.primaryColor, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Target', style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          )),
                          const SizedBox(height: 2),
                          Text(parsed.target!, style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                        ],
                      ),
                    ),
                    if (parsed.maxHops != null || parsed.packetSize != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (parsed.maxHops != null)
                            _SmallChip(text: '${parsed.maxHops} hops max'),
                          if (parsed.packetSize != null)
                            _SmallChip(text: '${parsed.packetSize} byte pkts'),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (parsed.hops.isNotEmpty) ...[
            Text('Route', style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            )),
            const SizedBox(height: 12),
            ...parsed.hops.asMap().entries.map((entry) {
              final index = entry.key;
              final hop = entry.value;
              final isLast = index == parsed.hops.length - 1;
              return _TracerouteHopTile(
                hop: hop,
                isLast: isLast,
                isDestination: isLast && hop.display.contains(parsed.target ?? ''),
              );
            }),
          ],
          if (!parsed.hasParsedData)
            SelectableText(
              parsed.rawLog,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.8), height: 1.4),
            ),
        ],
      ),
    );
  }

  Widget _buildSanityTestBody(BuildContext context, SanityTestResult parsed) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary card
          Card(
            margin: EdgeInsets.zero,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: parsed.allPassed
                ? Colors.green.withOpacity(0.12)
                : colorScheme.surfaceContainerHighest.withOpacity(0.6),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        parsed.allPassed ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        size: 32,
                        color: parsed.allPassed ? Colors.green : AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        parsed.allPassed ? 'All tests passed' : 'Sanity Test Summary',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SanitySummaryChip(
                        count: parsed.totalPassed,
                        label: 'Passed',
                        color: Colors.green,
                      ),
                      const SizedBox(width: 16),
                      _SanitySummaryChip(
                        count: parsed.totalFailed,
                        label: 'Failed',
                        color: AppTheme.errorColor,
                      ),
                    ],
                  ),
                  if (!parsed.allPassed && parsed.totalFailed > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Some sanity tests failed. Check details below.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Test sections (expandable)
          if (parsed.sections.isNotEmpty) ...[
            Text(
              'Tests',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            ...parsed.sections.map((section) => _SanityTestSectionTile(section: section)),
          ],
          // Fallback: show passed/failed lists if we have them but no sections
          if (parsed.sections.isEmpty && (parsed.passedTestNames.isNotEmpty || parsed.failedTestNames.isNotEmpty)) ...[
            if (parsed.passedTestNames.isNotEmpty) ...[
              _SanityListTile(
                title: 'Passed',
                names: parsed.passedTestNames,
                passed: true,
              ),
              const SizedBox(height: 12),
            ],
            if (parsed.failedTestNames.isNotEmpty)
              _SanityListTile(
                title: 'Failed',
                names: parsed.failedTestNames,
                passed: false,
              ),
          ],
          if (parsed.sections.isEmpty && parsed.passedTestNames.isEmpty && parsed.failedTestNames.isEmpty)
            SelectableText(
              parsed.rawLog,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.8), height: 1.4),
            ),
        ],
      ),
    );
  }
}

class _SanitySummaryChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _SanitySummaryChip({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          '$count',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class _SanityTestSectionTile extends StatefulWidget {
  final SanityTestSection section;

  const _SanityTestSectionTile({required this.section});

  @override
  State<_SanityTestSectionTile> createState() => _SanityTestSectionTileState();
}

class _SanityTestSectionTileState extends State<_SanityTestSectionTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final section = widget.section;
    final hasDetails = section.details.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      section.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 22,
                      color: section.passed ? Colors.green : AppTheme.errorColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        section.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (hasDetails)
                      Icon(
                        _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                  ],
                ),
                if (_expanded && hasDetails) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      section.details.join('\n'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SanityListTile extends StatelessWidget {
  final String title;
  final List<String> names;
  final bool passed;

  const _SanityListTile({required this.title, required this.names, required this.passed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 20,
                  color: passed ? Colors.green : AppTheme.errorColor,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...names.map((name) => Padding(
                  padding: const EdgeInsets.only(left: 28, bottom: 4),
                  child: Text(
                    '→ $name',
                    style: theme.textTheme.bodySmall,
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _TracerouteHopTile extends StatelessWidget {
  final TracerouteHop hop;
  final bool isLast;
  final bool isDestination;

  const _TracerouteHopTile({
    required this.hop,
    required this.isLast,
    required this.isDestination,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: hop.isTimeout
                      ? colorScheme.outline.withOpacity(0.3)
                      : (isDestination ? Colors.green : AppTheme.primaryColor).withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hop.isTimeout
                        ? colorScheme.outline
                        : (isDestination ? Colors.green : AppTheme.primaryColor),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${hop.hopNumber}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: hop.isTimeout ? colorScheme.onSurface.withOpacity(0.6) : null,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 12,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: colorScheme.outline.withOpacity(0.3),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Material(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hop.display,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: hop.isTimeout ? FontWeight.normal : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (hop.timeMs != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDestination ? Colors.green : AppTheme.primaryColor).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${hop.timeMs!.toStringAsFixed(hop.timeMs! >= 10 ? 1 : 3)} ms',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Text(
                        '*',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.outline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                )),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String text;

  const _SmallChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _SpeedCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _SpeedCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(label, style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                )),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(unit, style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            )),
          ],
        ),
      ),
    );
  }
}
