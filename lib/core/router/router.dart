import 'package:go_router/go_router.dart';

import '../error_screen.dart';
import '../../features/home/home.dart';

abstract class AppRouter {
  AppRouter._();

  static final routerConfig = GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const HomeScreen(),
      ),
    ],
    errorBuilder: (_, _) => const ErrorScreen(),
  );
}
