import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
            onTap: () => _openPlaceholder(context, "Speed test",
                "Run a network speed test. API integration coming soon."),
          ),
          const SizedBox(height: 12),
          _buildSubsegmentCard(
            context,
            title: "Traceroute",
            subtitle: "Trace the route to a host",
            icon: Icons.route_rounded,
            color: Colors.orange,
            onTap: () => _openPlaceholder(context, "Traceroute",
                "View hop-by-hop path to a destination. API integration coming soon."),
          ),
          const SizedBox(height: 12),
          _buildSubsegmentCard(
            context,
            title: "Sanity test",
            subtitle: "Quick connectivity and health checks",
            icon: Icons.health_and_safety_rounded,
            color: Colors.green,
            onTap: () => _openPlaceholder(context, "Sanity test",
                "Run basic sanity checks on the router. API integration coming soon."),
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

  void _openPlaceholder(BuildContext context, String title, String message) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => _PlaceholderScreen(title: title, message: message),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final String message;

  const _PlaceholderScreen({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.build_circle_outlined,
                size: 80,
                color: AppTheme.primaryColor.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
