import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../utils/ui_state.dart';
import '../viewmodels/thermostat_viewmodel.dart';
import '../viewmodels/smart_home_viewmodel.dart';

class ThermostatControlScreen extends StatelessWidget {
  final SmartDevice device;

  const ThermostatControlScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThermostatViewModel(nodeId: device.nodeId),
      child: Builder(
        builder: (context) => _ThermostatControlBody(device: device),
      ),
    );
  }
}

class _ThermostatControlBody extends StatefulWidget {
  final SmartDevice device;

  const _ThermostatControlBody({required this.device});

  @override
  State<_ThermostatControlBody> createState() => _ThermostatControlBodyState();
}

class _ThermostatControlBodyState extends State<_ThermostatControlBody> {
  double? _localHeatSetpoint;
  double? _localCoolSetpoint;
  bool _localInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ThermostatViewModel>().load();
    });
  }

  void _syncLocalFromTs(ThermostatState ts) {
    if (!_localInitialized && mounted) {
      _localInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _localHeatSetpoint = ts.heatSetpoint;
            _localCoolSetpoint = ts.coolSetpoint;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.device.label),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmRemove(context),
            ),
          ],
        ),
        body: Consumer<ThermostatViewModel>(
          builder: (context, vm, _) {
            if (vm.operationResult != null) {
              final result = vm.operationResult!;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (result.status == UiStatus.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.data!), backgroundColor: Colors.green),
                  );
                  vm.clearOperationResult();
                } else if (result.status == UiStatus.error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.message!), backgroundColor: Colors.red),
                  );
                  vm.clearOperationResult();
                }
              });
            }

            if (vm.state.status == UiStatus.loading && vm.state.data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (vm.state.status == UiStatus.error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${vm.state.message}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => vm.load(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final ts = vm.state.data!;
            _syncLocalFromTs(ts);
            final heatSetpoint = _localHeatSetpoint ?? ts.heatSetpoint;
            final coolSetpoint = _localCoolSetpoint ?? ts.coolSetpoint;

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Node ID: ${widget.device.nodeId}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                            const SizedBox(height: 4),
                            Text('Device: ${widget.device.deviceClass}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AmbientBar(
                        localTemperature: ts.localTemperature,
                        heatSetpoint: ts.heatSetpoint,
                        coolSetpoint: ts.coolSetpoint,
                      ),
                      const SizedBox(height: 24),
                      _ThermostatDial(
                        heatSetpoint: heatSetpoint,
                        coolSetpoint: coolSetpoint,
                        onHeatChanged: (v) {
                          setState(() {
                            _localHeatSetpoint = v;
                            _localCoolSetpoint ??= ts.coolSetpoint;
                            if (_localCoolSetpoint! < v) _localCoolSetpoint = v;
                          });
                        },
                        onCoolChanged: (v) {
                          setState(() {
                            _localCoolSetpoint = v;
                            _localHeatSetpoint ??= ts.heatSetpoint;
                            if (_localHeatSetpoint! > v) _localHeatSetpoint = v;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final heat = _localHeatSetpoint ?? ts.heatSetpoint;
                            final cool = _localCoolSetpoint ?? ts.coolSetpoint;
                            if (heat != ts.heatSetpoint) vm.setHeatSetpoint(heat);
                            if (cool != ts.coolSetpoint) vm.setCoolSetpoint(cool);
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ModeSection(
                        currentMode: ts.systemMode,
                        onModeSelected: vm.setSystemMode,
                      ),
                    ],
                  ),
                ),
                if (vm.isOperationLoading)
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
          },
        ),
      );
  }

  void _confirmRemove(BuildContext context) {
    final vm = context.read<SmartHomeViewModel>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove device'),
        content: const Text('Remove this device from your smart home?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              vm.removeDevice(widget.device.nodeId);
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

class _AmbientBar extends StatelessWidget {
  final double localTemperature;
  final double heatSetpoint;
  final double coolSetpoint;

  const _AmbientBar({
    required this.localTemperature,
    required this.heatSetpoint,
    required this.coolSetpoint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? Colors.white12 : const Color(0xFFE8F4F8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _AmbientChip(
            icon: Icons.home_outlined,
            value: '${_formatTemp(localTemperature)}°C',
            label: '',
          ),
          _AmbientChip(
            icon: Icons.local_fire_department_outlined,
            value: '${_formatTemp(heatSetpoint)}°C',
            label: '',
          ),
          _AmbientChip(
            icon: Icons.ac_unit,
            value: '${_formatTemp(coolSetpoint)}°C',
            label: '',
          ),
        ],
      ),
    );
  }

  String _formatTemp(double c) => c.toStringAsFixed(c.truncateToDouble() == c ? 0 : 1);
}

class _AmbientChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _AmbientChip({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}

/// Slider scale: 7 (heat min) to 32 (cool max) °C.
const double _sliderMin = 7.0;
const double _sliderMax = 32.0;

class _ThermostatDial extends StatelessWidget {
  final double heatSetpoint;
  final double coolSetpoint;
  final ValueChanged<double> onHeatChanged;
  final ValueChanged<double> onCoolChanged;

  const _ThermostatDial({
    required this.heatSetpoint,
    required this.coolSetpoint,
    required this.onHeatChanged,
    required this.onCoolChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heatMin = ThermostatState.heatSetpointMinC;
    final heatMax = ThermostatState.heatSetpointMaxC;
    final coolMin = ThermostatState.coolSetpointMinC;
    final coolMax = ThermostatState.coolSetpointMaxC;

    // Clamp and ensure heat <= cool for RangeSlider
    final heat = heatSetpoint.clamp(heatMin, heatMax).clamp(heatMin, coolSetpoint);
    final cool = coolSetpoint.clamp(coolMin, coolMax).clamp(heatSetpoint, coolMax);
    final rangeValues = RangeValues(heat, cool);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department, size: 18, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  '${heatSetpoint.toStringAsFixed(1)}°C - ${coolSetpoint.toStringAsFixed(1)}°C',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Icon(Icons.ac_unit, size: 18, color: Colors.blue.shade700),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                rangeTrackShape: _ThreeSectionTrackShape(),
                rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 12),
                trackHeight: 12,
              ),
              child: RangeSlider(
                min: _sliderMin,
                max: _sliderMax,
                divisions: (_sliderMax - _sliderMin).round(),
                values: rangeValues,
                onChanged: (RangeValues v) {
                  final newHeat = v.start.clamp(heatMin, heatMax);
                  final newCool = v.end.clamp(coolMin, coolMax);
                  if (newHeat > newCool) {
                    onHeatChanged(newCool);
                    onCoolChanged(newCool);
                  } else {
                    onHeatChanged(newHeat);
                    onCoolChanged(newCool);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_sliderMin.round()}°C', style: theme.textTheme.bodySmall),
                  Text('${_sliderMax.round()}°C', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the range slider track in three sections: heat (red), between (grey), cool (blue).
class _ThreeSectionTrackShape extends RangeSliderTrackShape with BaseRangeSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset startThumbCenter,
    required Offset endThumbCenter,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final left = trackRect.left;
    final right = trackRect.right;
    final trackWidth = right - left;
    final startNorm = trackWidth > 0 ? ((startThumbCenter.dx - left) / trackWidth).clamp(0.0, 1.0) : 0.0;
    final endNorm = trackWidth > 0 ? ((endThumbCenter.dx - left) / trackWidth).clamp(0.0, 1.0) : 1.0;

    final canvas = context.canvas;
    final height = trackRect.height;

    // Section 1: heat setpoint (red) - from left to start thumb
    final heatWidth = (startNorm * trackWidth).clamp(0.0, trackWidth);
    final heatRect = Rect.fromLTWH(left, trackRect.top, heatWidth, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(heatRect, Radius.circular(height / 2)),
      Paint()..color = Colors.red.shade400,
    );
    // Section 2: in between (grey)
    final midLeft = left + heatWidth;
    final midWidth = (endNorm * trackWidth - startNorm * trackWidth).clamp(0.0, trackWidth);
    final midRect = Rect.fromLTWH(midLeft, trackRect.top, midWidth, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(midRect, Radius.circular(height / 2)),
      Paint()..color = Colors.grey.shade400,
    );
    // Section 3: cool setpoint (blue) - from end thumb to right
    final coolLeft = left + (endNorm * trackWidth).clamp(0.0, trackWidth);
    final coolRect = Rect.fromLTWH(coolLeft, trackRect.top, (right - coolLeft).clamp(0.0, trackWidth), height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(coolRect, Radius.circular(height / 2)),
      Paint()..color = Colors.blue.shade400,
    );
  }
}

class _ModeSection extends StatelessWidget {
  final String currentMode;
  final ValueChanged<String> onModeSelected;

  const _ModeSection({required this.currentMode, required this.onModeSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('System mode', style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ThermostatState.systemModes.map((mode) {
            final isSelected = currentMode == mode;
            return FilterChip(
              label: Text(_modeLabel(mode)),
              selected: isSelected,
              onSelected: (_) => onModeSelected(mode),
              selectedColor: theme.colorScheme.primary.withOpacity(0.3),
              checkmarkColor: theme.colorScheme.primary,
            );
          }).toList(),
        ),
      ],
    );
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'emergencyHeat':
        return 'Heat';
      case 'fanOnly':
        return 'Fan only';
      default:
        return mode[0].toUpperCase() + mode.substring(1);
    }
  }
}
