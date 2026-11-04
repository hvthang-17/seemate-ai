import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/get_it.dart';
import '../../../core/error.dart' as app_error;
import '../domain/models/city.dart';
import '../domain/use_cases/get_cities.dart';

final getCitiesProvider = Provider<GetCities>((ref) => getIt<GetCities>());

final homeCitiesProvider =
    NotifierProvider<HomeCitiesNotifier, AsyncValue<List<City>>?>(
      HomeCitiesNotifier.new,
    );

final class HomeCitiesNotifier extends Notifier<AsyncValue<List<City>>?> {
  @override
  AsyncValue<List<City>>? build() => null;

  Future<void> loadCities() async {
    if (state case AsyncLoading<List<City>>()) return;

    state = const AsyncLoading();
    final result = await ref.read(getCitiesProvider)();
    state = result.fold(
      (app_error.NetworkError error) => AsyncError(error, StackTrace.current),
      AsyncData.new,
    );
  }
}
