import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'repositories/router_repository.dart';
import 'repositories/smart_home_repository.dart';
import 'utils/router_mac_manager.dart';
import 'viewmodels/router_viewmodel.dart';
import 'viewmodels/smart_home_viewmodel.dart';
import 'theme/app_theme.dart';
import 'screens/mac_address_screen.dart';
import 'screens/overview_screen.dart';
import 'screens/connected_devices_screen.dart';
import 'screens/device_details_screen.dart';
import 'screens/router_settings_screen.dart';
import 'screens/smart_home_screen.dart';
import 'screens/light_control_screen.dart';
import 'screens/plug_control_screen.dart';
import 'screens/thermostat_control_screen.dart';
import 'screens/door_lock_control_screen.dart';
import 'screens/motion_sensor_control_screen.dart';
import 'screens/about_router_screen.dart';
import 'screens/troubleshooting_screen.dart';
import 'screens/firmware_upgrade_screen.dart';
import 'models/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Simple check for initial route
  final mac = await RouterMacManager.getMac();
  final initialRoute = (mac.isEmpty || mac == "mac:") ? '/mac_address' : '/overview';

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RouterViewModel()),
        ChangeNotifierProvider(create: (_) => SmartHomeViewModel()),
      ],
      child: MyApp(initialRoute: initialRoute),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IntellicaWifi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: initialRoute,
      routes: {
        '/mac_address': (context) => const MacAddressScreen(),
        '/overview': (context) => const OverviewScreen(),
        '/connected_devices': (context) => const ConnectedDevicesScreen(),
        '/smart_home': (context) => const SmartHomeScreen(),
        '/router_settings': (context) => const RouterSettingsScreen(),
        '/about_router': (context) => const AboutRouterScreen(),
        '/troubleshooting': (context) => const TroubleshootingScreen(),
        '/firmware_upgrade': (context) => const FirmwareUpgradeScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/device_details') {
          final deviceId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => DeviceDetailsScreen(deviceId: deviceId),
          );
        }
        if (settings.name == '/light_control') {
          final device = settings.arguments as SmartDevice;
          return MaterialPageRoute(
            builder: (context) => LightControlScreen(device: device),
          );
        }
        if (settings.name == '/plug_control') {
          final device = settings.arguments as SmartDevice;
          return MaterialPageRoute(
            builder: (context) => PlugControlScreen(device: device),
          );
        }
        if (settings.name == '/thermostat_control') {
          final device = settings.arguments as SmartDevice;
          return MaterialPageRoute(
            builder: (context) => ThermostatControlScreen(device: device),
          );
        }
        if (settings.name == '/door_lock_control') {
          final device = settings.arguments as SmartDevice;
          return MaterialPageRoute(
            builder: (context) => DoorLockControlScreen(device: device),
          );
        }
        if (settings.name == '/motion_sensor_control') {
          final device = settings.arguments as SmartDevice;
          return MaterialPageRoute(
            builder: (context) => MotionSensorControlScreen(device: device),
          );
        }
        return null;
      },
    );
  }
}
