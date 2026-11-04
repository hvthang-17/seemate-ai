import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/i18n/i18n.dart';
import '../../../shared/widgets/app_error_widget.dart';
import '../../../shared/widgets/app_loading_widget.dart';
import '../domain/models/city.dart';
import 'home_providers.dart';

final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeCitiesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.homeTitle)),
      body: SafeArea(
        child: switch (state) {
          null => _HomeEmptyState(
            onLoad: ref.read(homeCitiesProvider.notifier).loadCities,
          ),
          AsyncData<List<City>>(:final value) => _CityList(cities: value),
          AsyncError<List<City>>() => AppErrorWidget(
            message: context.l10n.homeLoadError,
            onRetry: ref.read(homeCitiesProvider.notifier).loadCities,
          ),
          AsyncLoading<List<City>>() => const AppLoadingWidget(),
          AsyncValue<List<City>>() => const AppLoadingWidget(),
        },
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState({required this.onLoad});

  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        onPressed: onLoad,
        child: Text(context.l10n.homeLoadCities),
      ),
    );
  }
}

class _CityList extends StatelessWidget {
  const _CityList({required this.cities});

  final List<City> cities;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: cities.length,
      itemBuilder: (context, index) {
        final city = cities[index];
        return ListTile(title: Text(city.name), subtitle: Text(city.id));
      },
    );
  }
}
