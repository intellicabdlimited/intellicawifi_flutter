import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../viewmodels/smart_home_viewmodel.dart';
import '../utils/ui_state.dart';

class PlugControlScreen extends StatefulWidget {
  final SmartDevice device;

  const PlugControlScreen({super.key, required this.device});

  @override
  State<PlugControlScreen> createState() => _PlugControlScreenState();
}

class _PlugControlScreenState extends State<PlugControlScreen> {
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
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditLabelDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmRemove(context),
          ),
        ],
      ),
      body: Consumer<SmartHomeViewModel>(
        builder: (context, vm, _) {
          if (vm.operationResult != null && ModalRoute.of(context)?.isCurrent == true) {
            final result = vm.operationResult!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (ModalRoute.of(context)?.isCurrent != true) return;
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

          final device = vm.devices.data?.firstWhere(
            (d) => d.nodeId == widget.device.nodeId,
            orElse: () => widget.device,
          ) ?? widget.device;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.power, size: 48, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(device.label, style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 4),
                              Text('Node ID: ${device.nodeId}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              Text('Device: ${device.deviceClass}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        Switch(
                          value: device.isOn,
                          onChanged: (val) => vm.toggleDevice(device.nodeId, device.isOn),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Schedule ON/OFF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showTimerDialog(context, device),
                  icon: const Icon(Icons.schedule),
                  label: const Text('Set timer'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditLabelDialog(BuildContext context) {
    final vm = context.read<SmartHomeViewModel>();
    final device = vm.devices.data?.firstWhere(
      (d) => d.nodeId == widget.device.nodeId,
      orElse: () => widget.device,
    ) ?? widget.device;
    final controller = TextEditingController(text: device.label);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit label'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Device label'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                vm.setDeviceLabel(device.nodeId, controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
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

  void _showTimerDialog(BuildContext context, SmartDevice device) {
    TimeOfDay? selectedTime;
    String? selectedAction;
    final vm = context.read<SmartHomeViewModel>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Set timer'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Time'),
                  trailing: Text(
                    selectedTime != null
                        ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                        : 'Select',
                  ),
                  onTap: () async {
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (time != null) setDialogState(() => selectedTime = time);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ChoiceChip(
                      label: const Text('ON'),
                      selected: selectedAction == 'on',
                      onSelected: (s) => setDialogState(() => selectedAction = s ? 'on' : null),
                    ),
                    ChoiceChip(
                      label: const Text('OFF'),
                      selected: selectedAction == 'off',
                      onSelected: (s) => setDialogState(() => selectedAction = s ? 'off' : null),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: (selectedTime != null && selectedAction != null)
                    ? () {
                        final now = DateTime.now();
                        final dt = DateTime(now.year, now.month, now.day, selectedTime!.hour, selectedTime!.minute);
                        final target = dt.isBefore(now) ? dt.add(const Duration(days: 1)) : dt;
                        final seconds = target.difference(now).inSeconds;
                        vm.setDeviceTimer(device.nodeId, seconds, selectedAction!);
                        Navigator.pop(ctx);
                      }
                    : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
