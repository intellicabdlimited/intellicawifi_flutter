import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'troubleshoot_result_screen.dart';
import '../services/post_upgrade_coordinator.dart';
import '../viewmodels/router_viewmodel.dart';
import '../utils/ui_state.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  bool _postUpgradeDialogShown = false;
  bool _postUpgradeFailureShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RouterViewModel>().loadRouterInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("IntellicaWifi"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<RouterViewModel>().loadRouterInfo(),
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            onPressed: () => _showRebootDialog(context),
          )
        ],
      ),
      body: Consumer<RouterViewModel>(
        builder: (context, viewModel, _) {
          _maybeShowPostUpgradePrompt(viewModel);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Builder(
                  builder: (context) {
                final infoState = viewModel.routerInfo;
                
                if (infoState.status == UiStatus.loading) {
                   return const Center(child: Padding(
                     padding: EdgeInsets.all(16.0),
                     child: CircularProgressIndicator(),
                   ));
                }

                final isSuccess = infoState.status == UiStatus.success;
                final isError = infoState.status == UiStatus.error;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.router, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            "Router MAC: ${
                                isSuccess 
                                  ? infoState.data?.deviceMac ?? "Unknown" 
                                  : (viewModel.routerMac ?? "Loading...")
                            }", 
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor
                            )
                          ),
                        ],
                      ),
                    ),

                    if (isError) 
                      Container(
                        margin: const EdgeInsets.only(bottom: 24.0),
                        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                           color: Colors.red.withOpacity(0.05),
                           borderRadius: BorderRadius.circular(16),
                           border: Border.all(color: Colors.red.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red[400]),
                            const SizedBox(height: 8),
                            Text(infoState.message ?? "Connection Failed", style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 8),
                             ElevatedButton.icon(
                              onPressed: viewModel.loadRouterInfo,
                              icon: const Icon(Icons.refresh),
                              label: const Text("Retry"),
                            ),
                          ],
                        ),
                       ),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                          if (isSuccess) ...[
                            _buildActionCard(
                                context,
                                "Connected Devices",
                                Icons.devices,
                                Colors.blue,
                                () => Navigator.pushNamed(context, '/connected_devices')),
                            _buildActionCard(context, "Smart Home", Icons.home_filled,
                                Colors.green,
                                () => Navigator.pushNamed(context, '/smart_home')),
                            _buildActionCard(context, "Configure SSID", Icons.wifi,
                                Colors.orange,
                                () => Navigator.pushNamed(context, '/router_settings')),
                             _buildActionCard(context, "About Router", Icons.info_outline,
                                Colors.teal,
                                () => Navigator.pushNamed(context, '/about_router')),
                            _buildActionCard(context, "Troubleshooting", Icons.build_circle_outlined,
                                Colors.amber,
                                () => Navigator.pushNamed(context, '/troubleshooting')),
                            _buildActionCard(context, "Firmware upgrade", Icons.system_update_rounded,
                                Colors.indigo,
                                () => Navigator.pushNamed(context, '/firmware_upgrade')),
                          ],
                          _buildActionCard(context, "Change MAC", Icons.edit,
                              Colors.purple,
                              () => Navigator.pushNamed(context, '/mac_address')),
                      ],
                    ),
                  ],
                );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }



  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showRebootDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reboot Router"),
        content: const Text("Are you sure you want to reboot the router?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<RouterViewModel>().rebootRouter();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Reboot command sent")),
              );
            },
            child: const Text("Reboot", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _maybeShowPostUpgradePrompt(RouterViewModel viewModel) {
    final result = viewModel.lastPostUpgradeRunResult;
    if (result == null) return;

    final status = result.status;
    if (status == PostUpgradeRunStatus.skippedUpgradeFailed &&
        !_postUpgradeFailureShown) {
      _postUpgradeFailureShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Previous firmware upgrade failed. Post-upgrade sanity check was skipped.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
        viewModel.clearPostUpgradeRunResult();
      });
      return;
    }
    if (status != PostUpgradeRunStatus.promptReady || _postUpgradeDialogShown) return;

    _postUpgradeDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Firmware upgraded successfully'),
          content: const Text('Do you want to run post-upgrade sanity test?'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await viewModel.clearPostUpgradePendingState();
              },
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await viewModel.clearPostUpgradePendingState();
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const TroubleshootResultScreen(
                      title: 'Sanity test',
                      parameterName: kSanityTestParameterName,
                    ),
                  ),
                );
              },
              child: const Text('Yes'),
            ),
          ],
        ),
      );
    });
  }
}
