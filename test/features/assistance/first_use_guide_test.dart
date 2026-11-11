import 'package:flutter/material.dart';
import 'package:flutter_agentic_starter/features/assistance/presentation/assistance_providers.dart';
import 'package:flutter_agentic_starter/features/assistance/presentation/first_use_guide.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/assistance_contracts.dart';
import 'package:flutter_agentic_starter/shared/i18n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Widget home(_GuideStore store, FakeSpeechCoordinator speech) => ProviderScope(
    overrides: [
      firstUseGuideStoreProvider.overrideWithValue(store),
      speechCoordinatorProvider.overrideWithValue(speech),
    ],
    child: const MaterialApp(
      locale: Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: FirstUseGuide(child: Scaffold(body: Text('SeeMate AI'))),
    ),
  );

  testWidgets('narrates on the first visit and remembers dismissal', (
    tester,
  ) async {
    final store = _GuideStore();
    final speech = FakeSpeechCoordinator();
    addTearDown(speech.dispose);
    await tester.pumpWidget(home(store, speech));
    await tester.pumpAndSettle();

    expect(find.text('Hướng dẫn sử dụng'), findsOneWidget);
    expect(speech.spokenUtterances.single, contains('Chào mừng bạn'));
    await tester.tap(find.text('Đóng hướng dẫn'));
    await tester.pumpAndSettle();
    expect(speech.currentState, SpeechState.idle);
    expect(store.seen, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(home(store, speech));
    await tester.pumpAndSettle();
    expect(find.text('Hướng dẫn sử dụng'), findsNothing);
    expect(speech.spokenUtterances, hasLength(1));
  });

  testWidgets('shows the written guide when offline voice is unavailable', (
    tester,
  ) async {
    final speech = FakeSpeechCoordinator(
      readiness: const VoiceReadiness(isAvailable: false, isOffline: false),
    );
    addTearDown(speech.dispose);
    await tester.pumpWidget(home(_GuideStore(), speech));
    await tester.pumpAndSettle();

    expect(find.textContaining('Chào mừng bạn'), findsOneWidget);
    expect(find.textContaining('ngoại tuyến'), findsOneWidget);
    expect(speech.spokenUtterances, isEmpty);
    await tester.tap(find.text('Đóng hướng dẫn'));
    await tester.pumpAndSettle();
    expect(find.text('Hướng dẫn sử dụng'), findsNothing);
  });
}

class _GuideStore implements SharedPreferencesAsync {
  final _values = <String, bool>{};

  bool get seen => _values.values.singleOrNull ?? false;

  @override
  Future<bool?> getBool(String key) async => _values[key];

  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
