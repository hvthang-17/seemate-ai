import 'package:go_router/go_router.dart';

import '../../features/assistance/presentation/assistance_screen.dart';
import '../../features/assistance/presentation/first_use_guide.dart';
import '../../features/home/home.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../error_screen.dart';

abstract class AppRouter {
  AppRouter._();

  static final routerConfig = GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const FirstUseGuide(child: AssistanceScreen()),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/cities-demo',
        builder: (_, _) => const HomeScreen(),
      ),
    ],
    errorBuilder: (_, _) => const ErrorScreen(),
  );
}
