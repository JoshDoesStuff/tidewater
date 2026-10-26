import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tidewater/app/providers/settings_providers.dart';

void main() {
  test('the faint-icon option is off by default and is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    expect(first.read(iconGhostProvider), isFalse);
    first.read(iconGhostProvider.notifier).set(true);
    first.dispose();

    final second = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    expect(second.read(iconGhostProvider), isTrue);
    second.dispose();
  });
}
