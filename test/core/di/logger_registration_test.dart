import 'package:flutter_agentic_starter/core/di/get_it.dart';
import 'package:flutter_agentic_starter/core/flavor_configurations.dart';
import 'package:flutter_agentic_starter/core/logger/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final profile in ConfigurationProfile.values) {
    test('registers the startup logger for ${profile.name}', () {
      final previous = ConfigurationProfile.current;
      addTearDown(() async {
        await getIt.reset();
        ConfigurationProfile.current = previous;
      });

      ConfigurationProfile.current = profile;
      configureDependencies();

      expect(getIt.isRegistered<Logger>(), isTrue);
    });
  }
}
