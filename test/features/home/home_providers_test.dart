import 'dart:async';

import 'package:flutter_agentic_starter/core/error.dart' as app_error;
import 'package:flutter_agentic_starter/features/home/domain/models/city.dart';
import 'package:flutter_agentic_starter/features/home/domain/repositories/city_repository.dart';
import 'package:flutter_agentic_starter/features/home/domain/use_cases/get_cities.dart';
import 'package:flutter_agentic_starter/features/home/presentation/home_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  test('starts empty, then exposes loading and city data', () async {
    final repository = _ControlledCityRepository();
    final container = ProviderContainer(
      overrides: [getCitiesProvider.overrideWithValue(GetCities(repository))],
    );
    addTearDown(container.dispose);

    expect(container.read(homeCitiesProvider), isNull);

    final load = container.read(homeCitiesProvider.notifier).loadCities();
    expect(container.read(homeCitiesProvider), isA<AsyncLoading<List<City>>>());

    const cities = [City(id: '1', name: 'Da Nang')];
    repository.complete(right(cities));
    await load;

    final state = container.read(homeCitiesProvider);
    expect(state, isA<AsyncData<List<City>>>());
    expect((state! as AsyncData<List<City>>).value, cities);
  });

  test('exposes a typed error when loading fails', () async {
    final repository = _ControlledCityRepository();
    final container = ProviderContainer(
      overrides: [getCitiesProvider.overrideWithValue(GetCities(repository))],
    );
    addTearDown(container.dispose);
    final error = app_error.Timeout(exception: Exception('timed out'));

    final load = container.read(homeCitiesProvider.notifier).loadCities();
    repository.complete(left(error));
    await load;

    final state = container.read(homeCitiesProvider);
    expect(state, isA<AsyncError<List<City>>>());
    expect((state! as AsyncError<List<City>>).error, same(error));
  });
}

final class _ControlledCityRepository implements CityRepository {
  final _result = Completer<Either<app_error.NetworkError, List<City>>>();

  @override
  Future<Either<app_error.NetworkError, List<City>>> getCities() =>
      _result.future;

  void complete(Either<app_error.NetworkError, List<City>> result) {
    _result.complete(result);
  }
}
