import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

import 'core/analytics/analytics_service.dart';
import 'core/cache/cache_manager.dart';
import 'core/camera/flutter_camera_driver.dart';
import 'core/connectivity/connectivity_service.dart';
import 'core/connectivity/offline_queue_service.dart';
import 'core/di/get_it.dart';
import 'core/logger/logger.dart';
import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'core/utils/utils.dart';
import 'features/assistance/presentation/assistance_camera_providers.dart';
import 'features/assistance/presentation/assistance_providers.dart';
import 'features/assistance/presentation/first_use_guide.dart';
import 'features/object_detection/data/mediapipe_object_detector.dart';
import 'features/settings/data/local_assistance_preferences_repository.dart';
import 'features/speech/data/android_speech_coordinator.dart';
import 'features/speech/data/android_voice_command_service.dart';
import 'features/text_reading/data/ml_kit_text_reader.dart';
import 'shared/i18n/generated/app_localizations.dart';

Future<void> initializeFlutterApp() async {
  // 1. Flutter engine must be ready before any platform channel calls.
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Hive — required by DiskCache and OfflineQueueService.
  await Hive.initFlutter();

  // 4. Dependency injection — all @LazySingleton/@Injectable classes registered.
  configureDependencies();

  // 5. Register CompositeAnalyticsProvider as AnalyticsService after DI is ready.
  registerCompositeAnalytics();

  // 6. Initialise CacheManager disk layer (opens Hive box).
  await getIt<CacheManager>().init();

  // 7. Start connectivity monitoring before any network calls.
  await getIt<ConnectivityService>().init();

  // 8. Initialise OfflineQueueService (opens Hive box, subscribes connectivity).
  await getIt<OfflineQueueService>().initialize();

  // 9. Logger.
  final logger = getIt<Logger>();

  // 10. Wire error handlers to Logger.
  FlutterError.onError = (FlutterErrorDetails details) {
    logger(details.exceptionAsString(), stackTrace: details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger(error.toString(), error: error, stackTrace: stack);
    return true;
  };

  // 11. Analytics — runs after DI is ready.
  await getIt<AnalyticsService>().initialize();

  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final androidPreferences = isAndroid
      ? SharedPreferencesAsync(
          options: const SharedPreferencesAsyncAndroidOptions(
            backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
          ),
        )
      : null;
  final legacyAndroidPreferences = isAndroid ? SharedPreferencesAsync() : null;
  final preferencesRepository = LocalAssistancePreferencesRepository(
    preferences: androidPreferences,
    legacyPreferences: legacyAndroidPreferences,
  );

  runApp(
    ProviderScope(
      overrides: [
        preferencesRepoProvider.overrideWithValue(preferencesRepository),
        if (androidPreferences != null) ...[
          firstUseGuideStoreProvider.overrideWithValue(androidPreferences),
          legacyGuideStoreProvider.overrideWithValue(legacyAndroidPreferences),
          cameraDriverProvider.overrideWith((ref) => FlutterCameraDriver()),
          cameraDetectionEnabledProvider.overrideWithValue(true),
          voiceCommandProvider.overrideWith((ref) {
            final service = AndroidVoiceCommandService();
            ref.onDispose(service.dispose);
            return service;
          }),
          speechCoordinatorProvider.overrideWith((ref) {
            final coordinator = AndroidSpeechCoordinator();
            var disposed = false;
            unawaited(
              preferencesRepository.loadPreferences().then((result) async {
                final preferences = result.getRight().toNullable();
                if (!disposed && preferences != null) {
                  await applySpeechPreferences(coordinator, preferences);
                }
              }),
            );
            ref.onDispose(() {
              disposed = true;
              coordinator.dispose();
            });
            return coordinator;
          }),
          textReaderProvider.overrideWith((ref) {
            final reader = MlKitTextReader();
            ref.onDispose(reader.dispose);
            return reader;
          }),
          objectDetectorProvider.overrideWith((ref) {
            final detector = MediaPipeObjectDetector();
            ref.onDispose(detector.dispose);
            return detector;
          }),
        ],
      ],
      child: const App(),
    ),
  );
}

final class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => const AppView();
}

final class AppView extends StatefulWidget {
  const AppView({super.key});

  @override
  State<AppView> createState() => AppViewState();

  static AppViewState of(BuildContext context) =>
      context.findAncestorStateOfType<AppViewState>()!;
}

final class AppViewState extends State<AppView> {
  ThemeMode _themeMode = ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    safeSetState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(430, 932),
      minTextAdapt: true,
      child: MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).homeTitle,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: AppRouter.routerConfig,
        themeMode: _themeMode,
      ),
    );
  }
}
