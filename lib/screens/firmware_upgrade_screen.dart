import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Dummy static data for new firmware (replace with API later).
const _dummyFirmware = (
  version: '2.4.1',
  releaseDate: '2025-02-20',
  size: '24.5 MB',
  releaseNotes: '''
• Improved Wi-Fi stability and range
• Security patches and bug fixes
• Updated DNS and firewall rules
• Performance optimizations
''',
);

class FirmwareUpgradeScreen extends StatelessWidget {
  const FirmwareUpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Firmware upgrade"),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFirmwareDetailsCard(context),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 24.0),
            child: ElevatedButton.icon(
              onPressed: () => _showUpgradeConfirmation(context),
              icon: const Icon(Icons.system_update_rounded),
              label: const Text("Trigger firmware upgrade"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirmwareDetailsCard(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withOpacity(0.7);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 28,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "New firmware available",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Version ${_dummyFirmware.version}",
                        style: TextStyle(fontSize: 14, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow(context, "Version", _dummyFirmware.version),
            const SizedBox(height: 10),
            _buildDetailRow(context, "Release date", _dummyFirmware.releaseDate),
            const SizedBox(height: 10),
            _buildDetailRow(context, "Size", _dummyFirmware.size),
            const SizedBox(height: 16),
            Text(
              "Release notes",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                ),
              ),
              child: Text(
                _dummyFirmware.releaseNotes.trim(),
                style: TextStyle(fontSize: 13, height: 1.4, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withOpacity(0.7);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: muted)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface)),
      ],
    );
  }

  void _showUpgradeConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Firmware upgrade"),
        content: const Text(
          "Do you want to start the firmware upgrade? The router may reboot during the process. Ensure you are not performing critical tasks.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Firmware upgrade triggered. API integration coming soon.")),
              );
            },
            child: const Text("Upgrade"),
          ),
        ],
      ),
    );
  }
}
