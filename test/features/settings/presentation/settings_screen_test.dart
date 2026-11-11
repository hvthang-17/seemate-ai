import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agentic_starter/features/assistance/presentation/assistance_providers.dart';
import 'package:flutter_agentic_starter/features/settings/presentation/settings_screen.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/assistance_contracts.dart';
import 'package:flutter_agentic_starter/shared/i18n/generated/app_localizations.dart';

void main() {
  testWidgets('loads and displays initial preferences, saves updates', (tester) async {
    final fakeRepo = FakeAssistancePreferencesRepository(
      initialPreferences: const AssistancePreferences(
        speechRate: 1.0,
        duplicateSuppressionInterval: Duration(seconds: 2),
        spokenFeedbackEnabled: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesRepoProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cài đặt'), findsOneWidget);
    expect(find.textContaining('Tốc độ đọc giọng nói: 1.0x'), findsOneWidget);
    expect(find.textContaining('Khoảng thời gian chống lặp thông báo (giây): 2s'), findsOneWidget);
    expect(find.text('Phản hồi bằng giọng nói'), findsOneWidget);

    // Tap Save button
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Đã lưu cài đặt thành công'), findsOneWidget);
  });

  for (final retry in [true, false]) {
    testWidgets(
      retry
          ? 'retries a failed load and displays the saved values'
          : 'clears a load error after saving the displayed values',
      (tester) async {
        final repo = FakeAssistancePreferencesRepository(
          initialPreferences: const AssistancePreferences(speechRate: 1.5),
          failOnLoad: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [preferencesRepoProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              locale: Locale('vi'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final warning = find.textContaining('Không thể tải cài đặt đã lưu');
        expect(warning, findsOneWidget);
        if (retry) {
          repo.failOnLoad = false;
          await tester.tap(find.text('Thử lại'));
        } else {
          await tester.tap(find.text('Lưu'));
        }
        await tester.pumpAndSettle();

        expect(warning, findsNothing);
        if (retry) {
          expect(find.textContaining('1.5x'), findsOneWidget);
        } else {
          expect(repo.current.speechRate, 1.0);
          expect(find.text('Đã lưu cài đặt thành công'), findsOneWidget);
        }
      },
    );
  }
}
