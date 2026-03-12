import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../viewmodels/smart_home_viewmodel.dart';
import '../utils/ui_state.dart';
import '../models/models.dart';
import '../widgets/circular_color_picker.dart';
import '../widgets/zigbee_circular_color_picker.dart';

import 'qr_scanner_screen.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';

class SmartHomeScreen extends StatefulWidget {
  const SmartHomeScreen({super.key});

  @override
  State<SmartHomeScreen> createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends State<SmartHomeScreen> {
  // Local state for wifi is now in ViewModel

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWifiConfig();
    });
  }

  Future<void> _checkWifiConfig() async {
    if (!mounted) return;
    final vm = context.read<SmartHomeViewModel>();
    
    // Check config
    await vm.loadWifiConfig();

    if (!vm.isWifiConfigured) {
      if (mounted) {
        _showWifiConfigDialog(isMandatory: true);
      }
    }
    
    if (mounted) {
      vm.loadDevices();
    }
  }

  void _showWifiConfigDialog({bool isMandatory = false}) {
    final vm = context.read<SmartHomeViewModel>();
    final ssidController = TextEditingController(text: vm.ssid);
    final passController = TextEditingController(text: vm.password);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isObscured = true;
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Configure WiFi"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Enter WiFi details for smart devices."),
                  const SizedBox(height: 12),
                  TextField(
                      controller: ssidController,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        labelText: "SSID",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.wifi_find),
                          onPressed: () => _scanAndSelectWifi(context, ssidController),
                        ),
                      )),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passController,
                    enabled: !isSaving,
                    decoration: InputDecoration(
                      labelText: "Password",
                      suffixIcon: IconButton(
                        icon: Icon(isObscured
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () {
                          setDialogState(() {
                            isObscured = !isObscured;
                          });
                        },
                      ),
                    ),
                    obscureText: isObscured,
                  ),
                ],
              ),
              actions: [
                if (!isSaving)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (isMandatory) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text("Cancel"),
                  ),
                if (isSaving)
                  const SizedBox(
                    width: 24, 
                    height: 24, 
                    child: CircularProgressIndicator(strokeWidth: 2.0)
                  )
                else
                  ElevatedButton(
                    onPressed: () async {
                      if (ssidController.text.isNotEmpty &&
                          passController.text.isNotEmpty) {
                        
                        setDialogState(() {
                          isSaving = true;
                        });

                        final success = await vm.saveWifiConfig(
                            ssidController.text, passController.text);
                        
                        if (mounted) {
                           if (success) {
                             Navigator.pop(ctx);
                             vm.loadDevices();
                           } else {
                             setDialogState(() {
                               isSaving = false;
                             });
                           }
                        }
                      }
                    },
                    child: const Text("Save"),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Home"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showWifiConfigDialog(isMandatory: false),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<SmartHomeViewModel>().loadDevices(),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDeviceTypeDialog(),
        child: const Icon(Icons.add),
      ),
      body: Consumer<SmartHomeViewModel>(
        builder: (context, vm, child) {
          // Listen for operation result
          if (vm.operationResult != null) {
            final result = vm.operationResult!;
            // Using addPostFrameCallback to avoid setstate during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (result.status == UiStatus.success) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.data!), backgroundColor: Colors.green));
                  vm.clearOperationResult();
              } else if (result.status == UiStatus.error) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message!), backgroundColor: Colors.red));
                  vm.clearOperationResult();
              }
            });
          }
        
          if (vm.devices.status == UiStatus.loading && !vm.isOperationLoading) { // don't hide list if just op loading
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.devices.status == UiStatus.error) {
            return Center(child: Text("Error: ${vm.devices.message}"));
          }

          final devices = vm.devices.data ?? [];
          
          return Stack(
            children: [
              if (devices.isEmpty)
                const Center(child: Text("No smart devices found.")),
              if (devices.isNotEmpty)
                ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return _buildDeviceCard(device, vm);
                  },
                ),
                
              if (vm.isOperationLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                         child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             CircularProgressIndicator(),
                             SizedBox(height: 16),
                             Text("Processing..."),
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

  Widget _buildDeviceCard(SmartDevice device, SmartHomeViewModel vm) {
    final isLight = device.deviceClass == "light";
    final driver = device.driver;
    // Icon and color based on driver when available, else deviceClass
    final IconData deviceIcon;
    final Color iconColor;
    if (driver == "zigbeeLight") {
      deviceIcon = Icons.lightbulb_outline;
      iconColor = Colors.amber;
    } else if (driver == "matterLight") {
      deviceIcon = Icons.lightbulb;
      iconColor = Colors.orange;
    } else if (driver == "matterPlug" || driver == "zigbeePlug") {
      deviceIcon = Icons.power;
      iconColor = Colors.blue;
    } else {
      deviceIcon = isLight ? Icons.lightbulb : Icons.power;
      iconColor = isLight ? Colors.orange : Colors.blue;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  deviceIcon,
                  size: 32,
                  color: iconColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(device.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showEditLabelDialog(device),
                          ),
                        ],
                      ),
                      Text(
                        device.driver.isNotEmpty
                            ? "Class: ${device.deviceClass}, Driver: ${device.driver}"
                            : "Class: ${device.deviceClass}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: device.isOn,
                  onChanged: (val) {
                    if (driver == "zigbeeLight") {
                      vm.toggleZigbeeDevice(device.nodeId, device.isOn);
                    } else {
                      vm.toggleDevice(device.nodeId, device.isOn);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => vm.removeDevice(device.nodeId),
                ),
              ],
            ),
            if (isLight) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (driver == "zigbeeLight") ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showZigbeeColorPickerDialog(device),
                        icon: const Icon(Icons.palette, size: 18),
                        label: const Text("", style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showZigbeeBrightnessDialog(device),
                        icon: const Icon(Icons.wb_sunny, size: 18),
                        label: const Text("", style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showZigbeeColorTempDialog(device),
                        icon: const Icon(Icons.thermostat, size: 18),
                        label: const Text("", style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showColorPickerWithDialog(device),
                        icon: const Icon(Icons.palette, size: 18),
                        label: const Text("", style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showBrightnessDialog(device),
                        icon: const Icon(Icons.wb_sunny, size: 18),
                        label: const Text("", style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showSaturationDialog(device),
                        icon: const Icon(Icons.contrast, size: 18),
                        label: const Text("", style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
            const Divider(),
            const SizedBox(height: 8),
            if (driver != "zigbeeLight") _buildTimerSection(device, vm),
          ],
        ),
      ),
    );
  }

  void _showColorPickerWithDialog(SmartDevice device) {
    String selectedColor = "Custom"; // You might want to map hue to name if possible, or leave as Custom
    int selectedHue = device.hue;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Select Color"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Device: ${device.nodeId}", style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              CircularColorPicker(
                selectedHue: selectedHue,
                onColorSelected: (name, hue) {
                  selectedColor = name;
                  selectedHue = hue;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<SmartHomeViewModel>().setDeviceColor(
                    device.nodeId, selectedHue);
                Navigator.pop(ctx);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _showBrightnessDialog(SmartDevice device) {
    double value = device.brightness.toDouble();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Adjust Brightness"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Device: ${device.nodeId}", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  Text("${value.round()}%", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Slider(
                    value: value,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: value.round().toString(),
                    onChanged: (val) {
                      setState(() {
                        value = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    context.read<SmartHomeViewModel>().setDeviceBrightness(
                        device.nodeId, value.round());
                    Navigator.pop(ctx);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showSaturationDialog(SmartDevice device) {
    double value = device.saturation.toDouble();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Adjust Saturation"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Device: ${device.nodeId}", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  Text("${value.round()}%", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Slider(
                    value: value,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: value.round().toString(),
                    onChanged: (val) {
                      setState(() {
                        value = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    context.read<SmartHomeViewModel>().setDeviceSaturation(
                        device.nodeId, value.round());
                    Navigator.pop(ctx);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _showZigbeeColorPickerDialog(SmartDevice device) async {
    final vm = context.read<SmartHomeViewModel>();
    final state = await vm.getZigbeeState(device.nodeId);
    final initialX = state?.colorX ?? 0.700;
    final initialY = state?.colorY ?? 0.300;
    double selectedX = initialX;
    double selectedY = initialY;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Select Color"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Device: ${device.nodeId}", style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ZigbeeCircularColorPicker(
                initialX: initialX,
                initialY: initialY,
                onColorSelected: (name, x, y) {
                  selectedX = x;
                  selectedY = y;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<SmartHomeViewModel>().setZigbeeColorXY(device.nodeId, selectedX, selectedY);
                Navigator.pop(ctx);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showZigbeeColorTempDialog(SmartDevice device) async {
    final vm = context.read<SmartHomeViewModel>();
    final state = await vm.getZigbeeState(device.nodeId);
    double percent = (state?.colorTempPercent ?? 50).toDouble().clamp(1.0, 100.0);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final value = (153 + (347 * percent / 100)).round();
            return AlertDialog(
              title: const Text("Color Temperature"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Device: ${device.nodeId}", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  Text("${percent.round()}% • $value K", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      const Text("Cool", style: TextStyle(fontSize: 12, color: Colors.blue)),
                      Expanded(
                        child: Slider(
                          value: percent,
                          min: 1,
                          max: 100,
                          divisions: 99,
                          label: percent.round().toString(),
                          onChanged: (val) => setState(() => percent = val),
                        ),
                      ),
                      const Text("Warm", style: TextStyle(fontSize: 12, color: Colors.orange)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () {
                    context.read<SmartHomeViewModel>().setZigbeeColorTemp(device.nodeId, percent.round());
                    Navigator.pop(ctx);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showZigbeeBrightnessDialog(SmartDevice device) {
    double value = device.brightness.toDouble();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Adjust Brightness"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Device: ${device.nodeId}", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  Text("${value.round()}%", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Slider(
                    value: value,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: value.round().toString(),
                    onChanged: (val) => setState(() => value = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () {
                    context.read<SmartHomeViewModel>().setZigbeeBrightness(device.nodeId, value.round());
                    Navigator.pop(ctx);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeviceTypeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Device"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.smart_toy),
              title: const Text("Matter Device"),
              onTap: () {
                Navigator.pop(ctx);
                _showAddOptions();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bluetooth_searching),
              title: const Text("Zigbee Device"),
              onTap: () {
                Navigator.pop(ctx);
                _showZigbeeDiscoveryDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Add Device", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.keyboard),
                title: const Text('Enter Code'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddDeviceDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('Scan QR Code'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                  );
                  if (result != null && result is String) {
                    if (mounted) {
                      context.read<SmartHomeViewModel>().commissionDevice(result);
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showZigbeeDiscoveryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Zigbee Device"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Start discovery to find nearby Zigbee devices.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _startZigbeeDiscoveryFlow(ctx),
                  icon: const Icon(Icons.search),
                  label: const Text("Discovery Start"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startZigbeeDiscoveryFlow(BuildContext dialogContext) async {
    final vm = context.read<SmartHomeViewModel>();
    final success = await vm.startZigbeeDiscovery();
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to start discovery"), backgroundColor: Colors.red),
      );
      return;
    }
    await _showZigbeeWaitingAndFinish(dialogContext);
  }

  Future<void> _showZigbeeWaitingAndFinish(BuildContext dialogContext) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ZigbeeWaitingDialog(
        totalSeconds: 15,
        onComplete: () => Navigator.of(ctx).pop(),
      ),
    );

    if (!mounted) return;
    Navigator.of(dialogContext).pop();
    await context.read<SmartHomeViewModel>().stopZigbeeDiscoveryAndRefresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Discovery complete. Device list updated."), backgroundColor: Colors.green),
      );
    }
  }

  void _showAddDeviceDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Device"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Device Pairing Code"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              context.read<SmartHomeViewModel>().commissionDevice(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _showEditLabelDialog(SmartDevice device) {
    final controller = TextEditingController(text: device.label);
    final vm = context.read<SmartHomeViewModel>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Label"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Device Label"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                if (device.driver == "zigbeeLight") {
                  vm.setZigbeeLabel(device.nodeId, controller.text);
                } else {
                  vm.setDeviceLabel(device.nodeId, controller.text);
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerSection(SmartDevice device, SmartHomeViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Schedule ON/OFF",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showTimerDialog(device),
                icon: const Icon(Icons.schedule, size: 18),
                label: const Text("Set Timer", style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showTimerDialog(SmartDevice device) {
    TimeOfDay? selectedTime;
    String? selectedAction;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Set Timer"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Device: ${device.nodeId}", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text("Select Time"),
                    trailing: Text(
                      selectedTime != null
                          ? "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}"
                          : "Not selected",
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedTime = time;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text("Select Action:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ChoiceChip(
                        label: const Text("ON"),
                        selected: selectedAction == "on",
                        onSelected: (selected) {
                          setDialogState(() {
                            selectedAction = selected ? "on" : null;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text("OFF"),
                        selected: selectedAction == "off",
                        onSelected: (selected) {
                          setDialogState(() {
                            selectedAction = selected ? "off" : null;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: (selectedTime != null && selectedAction != null)
                      ? () {
                          // Calculate time difference in seconds
                          final now = DateTime.now();
                          final selectedDateTime = DateTime(
                            now.year,
                            now.month,
                            now.day,
                            selectedTime!.hour,
                            selectedTime!.minute,
                          );
                          
                          // If selected time is in the past, assume it's for tomorrow
                          final targetDateTime = selectedDateTime.isBefore(now)
                              ? selectedDateTime.add(const Duration(days: 1))
                              : selectedDateTime;
                          
                          final difference = targetDateTime.difference(now);
                          final timeInSeconds = difference.inSeconds;
                          
                          context.read<SmartHomeViewModel>().setDeviceTimer(
                                device.nodeId,
                                timeInSeconds,
                                selectedAction!,
                              );
                          Navigator.pop(ctx);
                        }
                      : null,
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> _scanAndSelectWifi(BuildContext context, TextEditingController ssidController) async {
    // Check permissions
    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
      if (!status.isGranted) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permission required for WiFi scanning")));
         return;
      }
    }

    // Check if wifi is enabled
    final canScan = await WiFiScan.instance.canStartScan();
    if (canScan != CanStartScan.yes) {
         // Try to get results anyway if recently scanned, but warn if cannot scan
         if (canScan == CanStartScan.noLocationPermissionDenied) {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permission denied")));
           return;
         }
         // e.g. wifi disabled
         if (canScan == CanStartScan.noLocationServiceDisabled) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location service is disabled. Please enable it.")));
             return;
         }
    }

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => const Center(child: CircularProgressIndicator())
    );

    try {
      final result = await WiFiScan.instance.startScan();
      if (!result) {
         // Scan start failed, maybe throttled? 
         // Just try to get existing results
      } else {
        // Wait for scan to likely complete (Android usually takes a few seconds)
        await Future.delayed(const Duration(seconds: 4));
      }

      final results = await WiFiScan.instance.getScannedResults();
      
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close loading
      }

      if (results.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No networks found")));
        return;
      }

       // Filter empty SSIDs and duplicates
      final uniqueSsids = <String>{};
      final uniqueResults = results.where((r) {
        if (r.ssid.isEmpty) return false;
        if (uniqueSsids.contains(r.ssid)) return false;
        uniqueSsids.add(r.ssid);
        return true;
      }).toList();


      // Show list
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Select Network"),
            content: SizedBox(
               width: double.maxFinite,
               child: ListView.builder(
                 shrinkWrap: true,
                 itemCount: uniqueResults.length,
                 itemBuilder: (ctx, i) {
                   final accessPoint = uniqueResults[i];
                   return ListTile(
                     title: Text(accessPoint.ssid),
                     trailing: const Icon(Icons.wifi), 
                     onTap: () {
                       ssidController.text = accessPoint.ssid;
                       Navigator.pop(ctx);
                     },
                   );
                 },
               ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close loading if open
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}

class _ZigbeeWaitingDialog extends StatefulWidget {
  final int totalSeconds;
  final VoidCallback onComplete;

  const _ZigbeeWaitingDialog({
    required this.totalSeconds,
    required this.onComplete,
  });

  @override
  State<_ZigbeeWaitingDialog> createState() => _ZigbeeWaitingDialogState();
}

class _ZigbeeWaitingDialogState extends State<_ZigbeeWaitingDialog> {
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.totalSeconds;
    _runCountdown();
  }

  Future<void> _runCountdown() async {
    for (int i = 0; i < widget.totalSeconds; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _remaining = widget.totalSeconds - 1 - i);
    }
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Discovering Zigbee devices"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            "Please wait... $_remaining seconds",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
