import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../utils/ui_state.dart';
import '../viewmodels/door_lock_viewmodel.dart';
import '../viewmodels/smart_home_viewmodel.dart';

class DoorLockControlScreen extends StatelessWidget {
  final SmartDevice device;

  const DoorLockControlScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DoorLockViewModel(nodeId: device.nodeId),
      child: _DoorLockControlBody(device: device),
    );
  }
}

class _DoorLockControlBody extends StatefulWidget {
  final SmartDevice device;

  const _DoorLockControlBody({required this.device});

  @override
  State<_DoorLockControlBody> createState() => _DoorLockControlBodyState();
}

class _DoorLockControlBodyState extends State<_DoorLockControlBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DoorLockViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DoorLockViewModel, SmartHomeViewModel>(
      builder: (context, lockVm, homeVm, _) {
        if (lockVm.operationResult != null && ModalRoute.of(context)?.isCurrent == true) {
          final result = lockVm.operationResult!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (ModalRoute.of(context)?.isCurrent != true) return;
            if (result.status == UiStatus.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.data!), backgroundColor: Colors.green),
              );
              lockVm.clearOperationResult();
              if (result.data == DoorLockViewModel.labelUpdatedMessage) {
                homeVm.loadDevices();
              }
            } else if (result.status == UiStatus.error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.message!), backgroundColor: Colors.red),
              );
              lockVm.clearOperationResult();
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
        ) ?? widget.device;

        Widget body;
        if (lockVm.state.status == UiStatus.loading && lockVm.state.data == null) {
          body = const Center(child: CircularProgressIndicator());
        } else if (lockVm.state.status == UiStatus.error) {
          body = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${lockVm.state.message}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => lockVm.load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        } else {
          final isLocked = lockVm.state.data!;
          body = Stack(
            children: [
              SingleChildScrollView(
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
                              isLocked ? Icons.lock : Icons.lock_open,
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
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isLocked ? 'Locked' : 'Unlocked',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Switch(
                            value: isLocked,
                            onChanged: lockVm.isOperationLoading
                                ? null
                                : (v) => lockVm.setLocked(v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Turn on to lock and off to unlock.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              if (lockVm.isOperationLoading)
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
    final lockVm = context.read<DoorLockViewModel>();
    final homeVm = context.read<SmartHomeViewModel>();
    final listed = homeVm.devices.data?.firstWhere(
      (d) => d.nodeId == widget.device.nodeId,
      orElse: () => widget.device,
    ) ?? widget.device;
    final controller = TextEditingController(text: listed.label);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit label'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Door label'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              await lockVm.setLabel(text);
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
        content: const Text('Remove this device from your smart home?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              homeVm.removeDevice(widget.device.nodeId);
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
