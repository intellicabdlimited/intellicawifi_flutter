import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/air_sensor_background_scheduler.dart';
import '../services/air_sensor_notification_service.dart';
import '../utils/ui_state.dart';
import '../services/air_sensor_threshold_evaluator.dart';
import '../viewmodels/air_sensor_viewmodel.dart';
import '../viewmodels/smart_home_viewmodel.dart';

class AirSensorControlScreen extends StatelessWidget {
  final SmartDevice device;

  const AirSensorControlScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AirSensorViewModel(nodeId: device.nodeId),
      child: _AirSensorControlBody(device: device),
    );
  }
}

class _AirSensorControlBody extends StatefulWidget {
  final SmartDevice device;

  const _AirSensorControlBody({required this.device});

  @override
  State<_AirSensorControlBody> createState() => _AirSensorControlBodyState();
}

class _AirSensorControlBodyState extends State<_AirSensorControlBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AirSensorViewModel>().load();
    });
    _requestNotificationPermissionOnEntry();
  }

  Future<void> _requestNotificationPermissionOnEntry() async {
    await AirSensorNotificationService.instance.requestPostPermissions();
    if (await AirSensorNotificationService.instance.alertsEnabled()) {
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
      await AirSensorBackgroundScheduler.registerPeriodic();
    }
  }

  String _prettyKey(String key) {
    final b = StringBuffer();
    for (var i = 0; i < key.length; i++) {
      final c = key[i];
      if (i > 0 && c == c.toUpperCase() && c != c.toLowerCase()) {
        b.write(' ');
      }
      b.write(c);
    }
    return b.toString();
  }

  /// `matterXxxConcentration` + Max / Measured / Min
  static final RegExp _concentrationKey =
      RegExp(r'^(matter\w+Concentration)(Max|Measured|Min)$');

  static const Map<String, String> _concentrationCardTitle = {
    'matterCo2Concentration': 'CO₂',
    'matterCoConcentration': 'CO',
    'matterFormaldehydeConcentration': 'Formaldehyde',
    'matterNo2Concentration': 'NO₂',
    'matterO3Concentration': 'O₃',
    'matterPm10Concentration': 'PM10',
    'matterPm1Concentration': 'PM1',
    'matterPm25Concentration': 'PM2.5',
    'matterRadonConcentration': 'Radon',
    'matterTvocConcentration': 'TVOC',
  };

  String _concentrationTitle(String base) {
    return _concentrationCardTitle[base] ??
        _prettyKey(base.replaceFirst('matter', '').replaceAll('Concentration', '').trim());
  }

  Widget _readingRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Text(
                label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _miniRow(BuildContext context, String left, String right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(left, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              right,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDisplay(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2);
  }

  Future<void> _showLimitEditDialog(
    BuildContext context,
    AirSensorViewModel vm,
    String metricId,
    bool isMax,
    double currentValue,
  ) async {
    final controller = TextEditingController(text: _fmtDisplay(currentValue));
    final parsed = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${isMax ? 'max' : 'min'} value'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
          decoration: const InputDecoration(labelText: 'Value'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final next = double.tryParse(controller.text.trim());
              if (next == null) return;
              Navigator.of(ctx).pop(next);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (parsed == null) return;
    await vm.adjustLimit(metricId, isMax, parsed - currentValue);
  }

  Widget _limitAdjustRow(
    BuildContext context,
    AirSensorViewModel vm,
    String metricId,
    bool isMax,
    String label,
    String fallbackRaw,
  ) {
    final pair = vm.limits[metricId];
    final fallback = AirSensorThresholdEvaluator.parseNumeric(fallbackRaw);
    final value = isMax ? (pair?.max ?? fallback) : (pair?.min ?? fallback);
    final step = vm.stepForMetric(metricId);
    if (value == null) {
      return _miniRow(context, label, fallbackRaw);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            onPressed: () => vm.adjustLimit(metricId, isMax, -step),
          ),
          SizedBox(
            width: 64,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _showLimitEditDialog(context, vm, metricId, isMax, value),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _fmtDisplay(value),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline, size: 22),
            onPressed: () => vm.adjustLimit(metricId, isMax, step),
          ),
        ],
      ),
    );
  }

  /// Builds endpoint-1 reading widgets: single attributes, concentration cards, humidity & temperature.
  List<Widget> _buildEndpointReadingWidgets(
    BuildContext context,
    AirSensorState st,
    AirSensorViewModel vm,
  ) {
    final readings = Map<String, String>.from(st.readings);
    final widgets = <Widget>[];

    // --- Concentration triplets (Max / Measured / Min) ---
    final groups = <String, Map<String, String>>{};
    for (final e in readings.entries.toList()) {
      final m = _concentrationKey.firstMatch(e.key);
      if (m == null) continue;
      final base = m.group(1)!;
      final suffix = m.group(2)!;
      groups.putIfAbsent(base, () => {});
      groups[base]![suffix] = e.value;
    }
    for (final base in groups.keys) {
      readings.removeWhere((k, _) {
        final m = _concentrationKey.firstMatch(k);
        return m != null && m.group(1) == base;
      });
    }

    final humidity = <String, String>{};
    final temperature = <String, String>{};
    for (final e in readings.entries.toList()) {
      if (e.key.startsWith('matterRelativeHumidity')) {
        humidity[e.key] = e.value;
      } else if (e.key.startsWith('matterTemperature')) {
        temperature[e.key] = e.value;
      }
    }
    humidity.forEach((k, _) => readings.remove(k));
    temperature.forEach((k, _) => readings.remove(k));

    // --- Singles (remaining keys), stable sort ---
    final singleKeys = readings.keys.toList()..sort();

    for (final key in singleKeys) {
      widgets.add(_readingRow(context, _prettyKey(key), readings[key] ?? ''));
    }

    // Concentration cards: consistent order
    final bases = groups.keys.toList()
      ..sort((a, b) => _concentrationTitle(a).compareTo(_concentrationTitle(b)));
    for (final base in bases) {
      final g = groups[base]!;
      final rows = <Widget>[];
      if (g.containsKey('Max')) {
        rows.add(_limitAdjustRow(context, vm, base, true, 'Max', g['Max'] ?? ''));
      }
      if (g.containsKey('Measured')) {
        rows.add(_miniRow(context, 'Measured', g['Measured'] ?? ''));
      }
      if (g.containsKey('Min')) {
        rows.add(_limitAdjustRow(context, vm, base, false, 'Min', g['Min'] ?? ''));
      }
      if (rows.isNotEmpty) {
        widgets.add(
          _groupCard(
            context,
            title: '${_concentrationTitle(base)} concentration',
            children: rows,
          ),
        );
      }
    }

    if (humidity.isNotEmpty) {
      const humidityHandled = {
        'matterRelativeHumidityMaxPercent',
        'matterRelativeHumidityMinPercent',
        'matterRelativeHumidityPercent',
        'matterRelativeHumidityTolerancePercent',
      };
      final rows = <Widget>[];
      if (humidity.containsKey('matterRelativeHumidityMaxPercent')) {
        rows.add(_limitAdjustRow(
          context,
          vm,
          'relativeHumidity',
          true,
          'Max %',
          humidity['matterRelativeHumidityMaxPercent'] ?? '',
        ));
      }
      if (humidity.containsKey('matterRelativeHumidityMinPercent')) {
        rows.add(_limitAdjustRow(
          context,
          vm,
          'relativeHumidity',
          false,
          'Min %',
          humidity['matterRelativeHumidityMinPercent'] ?? '',
        ));
      }
      for (final k in [
        'matterRelativeHumidityPercent',
        'matterRelativeHumidityTolerancePercent',
      ]) {
        if (humidity.containsKey(k)) {
          rows.add(_miniRow(
            context,
            _prettyKey(k.replaceFirst('matterRelativeHumidity', '')),
            humidity[k] ?? '',
          ));
        }
      }
      for (final k in humidity.keys.toList()..sort()) {
        if (humidityHandled.contains(k)) continue;
        rows.add(_miniRow(
          context,
          _prettyKey(k.replaceFirst('matterRelativeHumidity', '')),
          humidity[k] ?? '',
        ));
      }
      widgets.add(_groupCard(context, title: 'Relative humidity', children: rows));
    }

    if (temperature.isNotEmpty) {
      const temperatureHandled = {
        'matterTemperatureMaxC',
        'matterTemperatureMinC',
        'matterTemperatureMeasuredC',
        'matterTemperatureToleranceC',
      };
      final rows = <Widget>[];
      if (temperature.containsKey('matterTemperatureMaxC')) {
        rows.add(_limitAdjustRow(
          context,
          vm,
          'temperature',
          true,
          'Max °C',
          temperature['matterTemperatureMaxC'] ?? '',
        ));
      }
      if (temperature.containsKey('matterTemperatureMinC')) {
        rows.add(_limitAdjustRow(
          context,
          vm,
          'temperature',
          false,
          'Min °C',
          temperature['matterTemperatureMinC'] ?? '',
        ));
      }
      for (final k in [
        'matterTemperatureMeasuredC',
        'matterTemperatureToleranceC',
      ]) {
        if (temperature.containsKey(k)) {
          rows.add(_miniRow(
            context,
            _prettyKey(k.replaceFirst('matterTemperature', '')),
            temperature[k] ?? '',
          ));
        }
      }
      for (final k in temperature.keys.toList()..sort()) {
        if (temperatureHandled.contains(k)) continue;
        rows.add(_miniRow(
          context,
          _prettyKey(k.replaceFirst('matterTemperature', '')),
          temperature[k] ?? '',
        ));
      }
      widgets.add(_groupCard(context, title: 'Temperature', children: rows));
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AirSensorViewModel, SmartHomeViewModel>(
      builder: (context, sensorVm, homeVm, _) {
        if (sensorVm.operationResult != null && ModalRoute.of(context)?.isCurrent == true) {
          final result = sensorVm.operationResult!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (ModalRoute.of(context)?.isCurrent != true) return;
            sensorVm.clearOperationResult();
            if (result.status == UiStatus.success &&
                result.data == AirSensorViewModel.labelUpdatedMessage) {
              homeVm.loadDevices();
            }
          });
        }

        if (homeVm.operationResult != null && ModalRoute.of(context)?.isCurrent == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (ModalRoute.of(context)?.isCurrent != true) return;
            homeVm.clearOperationResult();
          });
        }

        final listed = homeVm.devices.data?.firstWhere(
              (d) => d.nodeId == widget.device.nodeId,
              orElse: () => widget.device,
            ) ??
            widget.device;

        Widget body;
        if (sensorVm.state.status == UiStatus.loading && sensorVm.state.data == null) {
          body = const Center(child: CircularProgressIndicator());
        } else if (sensorVm.state.status == UiStatus.error) {
          body = SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Error: ${sensorVm.state.message}', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: () => sensorVm.load(),
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          );
        } else {
          final st = sensorVm.state.data!;
          body = Stack(
            children: [
              RefreshIndicator(
                onRefresh: () => sensorVm.load(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Icon(
                                Icons.air,
                                size: 48,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      listed.label,
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Node ID: ${listed.nodeId}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    Text(
                                      listed.driver.isNotEmpty
                                          ? 'Class: ${listed.deviceClass} · Driver: ${listed.driver}'
                                          : 'Class: ${listed.deviceClass}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._buildEndpointReadingWidgets(context, st, sensorVm),
                    ],
                  ),
                ),
              ),
              if (sensorVm.isOperationLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Updating...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(listed.label),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: sensorVm.isOperationLoading ? null : () => sensorVm.load(),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditLabelDialog(context),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmRemove(context),
              ),
            ],
          ),
          body: body,
        );
      },
    );
  }

  void _showEditLabelDialog(BuildContext context) {
    final sensorVm = context.read<AirSensorViewModel>();
    final homeVm = context.read<SmartHomeViewModel>();
    final listed = homeVm.devices.data?.firstWhere(
          (d) => d.nodeId == widget.device.nodeId,
          orElse: () => widget.device,
        ) ??
        widget.device;
    final controller = TextEditingController(text: listed.label);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit label'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Room / device label'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              await sensorVm.setLabel(text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    final homeVm = context.read<SmartHomeViewModel>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove device'),
        content: const Text('Remove this air sensor from your smart home?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              homeVm.removeAirSensorDevice(widget.device.nodeId);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
