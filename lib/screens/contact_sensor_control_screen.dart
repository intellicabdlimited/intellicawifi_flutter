import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../viewmodels/smart_home_viewmodel.dart';

class ContactSensorControlScreen extends StatelessWidget {
  final SmartDevice device;

  const ContactSensorControlScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SmartHomeViewModel>();
    final liveDevice = (vm.devices.data ?? const <SmartDevice>[])
        .cast<SmartDevice>()
        .firstWhere((d) => d.nodeId == device.nodeId, orElse: () => device);
    final displayState = liveDevice.isOn ? "Open" : "Closed";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Contact Sensor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // UI-only for now; later we'll fetch the real state from remote.
              vm.loadDevices();
            },
          ),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.sensors, size: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(device.label, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text('Node ID: ${device.nodeId}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          Text('Class: ${device.deviceClass}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('State', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      displayState,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Read-only device',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
              vm.removeDevice(device.nodeId);
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

