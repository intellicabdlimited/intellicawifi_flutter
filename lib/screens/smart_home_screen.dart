import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/smart_home_viewmodel.dart';
import '../utils/ui_state.dart';
import '../models/models.dart';
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
        onPressed: () => _showAddOptions(),
        child: const Icon(Icons.add),
      ),
      body: Consumer<SmartHomeViewModel>(
        builder: (context, vm, child) {
          // Listen for operation result
          if (vm.operationResult != null && ModalRoute.of(context)?.isCurrent == true) {
            final result = vm.operationResult!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (ModalRoute.of(context)?.isCurrent != true) return;
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

  void _openDeviceControl(SmartDevice device) {
    if (device.deviceClass == "thermostat") {
      Navigator.pushNamed(context, '/thermostat_control', arguments: device);
    } else if (device.deviceClass == "doorlock") {
      Navigator.pushNamed(context, '/door_lock_control', arguments: device);
    } else if (device.deviceClass == "sensor") {
      Navigator.pushNamed(context, '/air_sensor_control', arguments: device);
    } else if (device.deviceClass == "light") {
      Navigator.pushNamed(context, '/light_control', arguments: device);
    } else if (device.deviceClass == "plug") {
      Navigator.pushNamed(context, '/plug_control', arguments: device);
    } else {
      Navigator.pushNamed(context, '/light_control', arguments: device);
    }
  }

  Widget _buildDeviceCard(SmartDevice device, SmartHomeViewModel vm) {
    final isLight = device.deviceClass == "light";
    final isThermostat = device.deviceClass == "thermostat";
    final isDoorLock = device.deviceClass == "doorlock";
    final isAirSensor = device.deviceClass == "sensor";
    IconData icon;
    Color iconColor;
    if (isThermostat) {
      icon = Icons.thermostat;
      iconColor = Colors.blue.shade700;
    } else if (isDoorLock) {
      icon = Icons.door_front_door_outlined;
      iconColor = Theme.of(context).colorScheme.primary;
    } else if (isAirSensor) {
      icon = Icons.air;
      iconColor = Colors.teal.shade700;
    } else if (isLight) {
      icon = Icons.lightbulb;
      iconColor = Colors.orange;
    } else {
      icon = Icons.power;
      iconColor = Colors.blue;
    }

    return Card(
      child: InkWell(
        onTap: () => _openDeviceControl(device),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 36, color: iconColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("Class: ${device.deviceClass}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              if (!isThermostat && !isDoorLock && !isAirSensor)
                Switch(
                  value: device.isOn,
                  onChanged: (val) => vm.toggleDevice(device.nodeId, device.isOn),
                )
              else
                const SizedBox(width: 48),
              Icon(Icons.chevron_right, color: Colors.grey.shade600),
            ],
          ),
        ),
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
