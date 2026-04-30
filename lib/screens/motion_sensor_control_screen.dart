import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../viewmodels/motion_sensor_viewmodel.dart';
import '../viewmodels/smart_home_viewmodel.dart';

class MotionSensorControlScreen extends StatelessWidget {
  final SmartDevice device;

  const MotionSensorControlScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MotionSensorViewModel(nodeId: device.nodeId),
      child: _MotionSensorControlBody(device: device),
    );
  }
}

class _MotionSensorControlBody extends StatefulWidget {
  final SmartDevice device;

  const _MotionSensorControlBody({required this.device});

  @override
  State<_MotionSensorControlBody> createState() => _MotionSensorControlBodyState();
}

class _MotionSensorControlBodyState extends State<_MotionSensorControlBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MotionSensorViewModel>().connectAndListen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MotionSensorViewModel, SmartHomeViewModel>(
      builder: (context, motionVm, homeVm, _) {
        final listed = homeVm.devices.data?.firstWhere(
              (d) => d.nodeId == widget.device.nodeId,
              orElse: () => widget.device,
            ) ??
            widget.device;

        final statusText = motionVm.state.isOn ? 'Occupied' : 'Unoccupied';
        final statusColor = motionVm.state.isOn ? Colors.green : Colors.grey.shade700;

        return Scaffold(
          appBar: AppBar(
            title: Text(listed.label),
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Node ID: ${listed.nodeId}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  'Driver: ${listed.driver.isEmpty ? "N/A" : listed.driver}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.35),
                        width: 6,
                      ),
                      color: statusColor.withValues(alpha: 0.08),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          statusText,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          'Occupancy',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey.shade700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Illuminance',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      motionVm.state.illuminance,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Connection: ${_connectionLabel(motionVm.state.connectionStatus)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                if (motionVm.state.message != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    motionVm.state.message!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        );
      },
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

  String _connectionLabel(MotionMqttStatus status) {
    switch (status) {
      case MotionMqttStatus.connecting:
        return 'connecting';
      case MotionMqttStatus.connected:
        return 'connected';
      case MotionMqttStatus.disconnected:
        return 'disconnected';
    }
  }
}
