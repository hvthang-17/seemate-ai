import 'package:flutter/material.dart';
import 'package:flutter_agentic_starter/core/router/router.dart';
import 'package:flutter_agentic_starter/features/assistance/presentation/assistance_providers.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/assistance_contracts.dart';
import 'package:flutter_agentic_starter/shared/i18n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app router loads AssistanceScreen with accessible Vietnamese controls', (tester) async {
    final fakeCoordinator = FakeSpeechCoordinator();
    final fakeDetector = FakeObjectDetector();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speechCoordinatorProvider.overrideWithValue(fakeCoordinator),
          objectDetectorProvider.overrideWithValue(fakeDetector),
        ],
        child: MaterialApp.router(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: AppRouter.routerConfig,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(AppRouter.routerConfig.routeInformationProvider.value.uri.path, '/');
    expect(find.text('SeeMate AI'), findsOneWidget);
    expect(find.text('Dừng đọc'), findsOneWidget);
    expect(find.text('Nhận diện đồ vật'), findsOneWidget);
    expect(find.text('Tìm đồ vật'), findsOneWidget);
    expect(find.text('Đọc văn bản'), findsOneWidget);

    // Tap Dừng đọc
    await tester.tap(find.text('Dừng đọc'));
    await tester.pump();
    expect(fakeCoordinator.stopCallCount, 1);
  });
}
