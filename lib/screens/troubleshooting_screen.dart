import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'troubleshoot_result_screen.dart';

class TroubleshootingScreen extends StatelessWidget {
  const TroubleshootingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Troubleshooting"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSubsegmentCard(
            context,
            title: "Speed test",
            subtitle: "Measure download and upload speeds",
            icon: Icons.speed_rounded,
            color: Colors.blue,
            onTap: () => _openResultScreen(context, "Speed test", "Device.Bananapi.temp2"),
          ),
          const SizedBox(height: 12),
          _buildSubsegmentCard(
            context,
            title: "Traceroute",
            subtitle: "Trace the route to a host",
            icon: Icons.route_rounded,
            color: Colors.orange,
            onTap: () => _openResultScreen(context, "Traceroute", "Device.Bananapi.temp3"),
          ),
          const SizedBox(height: 12),
          _buildSubsegmentCard(
            context,
            title: "Sanity test",
            subtitle: "Quick connectivity and health checks",
            icon: Icons.health_and_safety_rounded,
            color: Colors.green,
            onTap: () => _openResultScreen(context, "Sanity test", "Device.Bananapi.temp1"),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsegmentCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openResultScreen(BuildContext context, String title, String parameterName) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => TroubleshootResultScreen(
          title: title,
          parameterName: parameterName,
        ),
      ),
    );
  }
}
