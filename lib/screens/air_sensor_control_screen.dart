import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../utils/ui_state.dart';
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

  @override
  Widget build(BuildContext context) {
    return Consumer2<AirSensorViewModel, SmartHomeViewModel>(
      builder: (context, sensorVm, homeVm, _) {
        if (sensorVm.operationResult != null && ModalRoute.of(context)?.isCurrent == true) {
          final result = sensorVm.operationResult!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (ModalRoute.of(context)?.isCurrent != true) return;
            if (result.status == UiStatus.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.data!), backgroundColor: Colors.green),
              );
              sensorVm.clearOperationResult();
              if (result.data == AirSensorViewModel.labelUpdatedMessage) {
                homeVm.loadDevices();
              }
            } else if (result.status == UiStatus.error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.message!), backgroundColor: Colors.red),
              );
              sensorVm.clearOperationResult();
            }
          });
        }

        if (homeVm.operationResult != null && ModalRoute.of(context)?.isCurrent == true) {
          final result = homeVm.operationResult!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (ModalRoute.of(context)?.isCurrent != true) return;
            if (result.status == UiStatus.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.data!), backgroundColor: Colors.green),
              );
              homeVm.clearOperationResult();
            } else if (result.status == UiStatus.error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.message!), backgroundColor: Colors.red),
              );
              homeVm.clearOperationResult();
            }
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
          body = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${sensorVm.state.message}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => sensorVm.load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
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
                                      'Device: ${listed.deviceClass}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    if (st.matterAirQuality != null) ...[
                                      const SizedBox(height: 8),
                                      Chip(
                                        label: Text('Air quality: ${st.matterAirQuality}'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                    if (st.endpointType != null)
                                      Text(
                                        'Type: ${st.endpointType}',
                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sensor readings (endpoint 1)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ...st.sortedReadingKeys().where((k) => k != 'label').map((key) {
                        final val = st.readings[key] ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    _prettyKey(key),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    val,
                                    textAlign: TextAlign.end,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
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
