import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/models/radio_station.dart';
import 'session_providers.dart';
import 'ui_providers.dart';

/// The internet radio stations the server keeps.
final radioStationsProvider = FutureProvider<List<RadioStation>>((ref) async {
  final list = await ref.watch(apiProvider).getRadioStations();
  return [...list]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

/// Adding, changing and removing stations. The server only lets admin accounts do
/// this, so a refusal is explained in a message instead of being thrown.
class RadioActions {
  RadioActions(this._ref);

  final Ref _ref;

  Future<bool> _try(Future<void> Function() change, String done) async {
    try {
      await change();
    } on ApiException catch (e) {
      _ref.read(toastProvider.notifier).show(
            e.isOffline ? 'Can\'t reach the server. Nothing was changed.' : 'Couldn\'t change the stations: ${e.message}',
            error: true,
          );
      return false;
    }
    _ref.invalidate(radioStationsProvider);
    _ref.read(toastProvider.notifier).show(done);
    return true;
  }

  Future<bool> add(String name, String streamUrl, String? homepageUrl) => _try(
        () => _ref.read(apiProvider).createRadioStation(name: name, streamUrl: streamUrl, homepageUrl: homepageUrl),
        'Added "$name".',
      );

  Future<bool> edit(RadioStation station, String name, String streamUrl, String? homepageUrl) => _try(
        () => _ref.read(apiProvider).updateRadioStation(station.id, name: name, streamUrl: streamUrl, homepageUrl: homepageUrl),
        'Saved "$name".',
      );

  Future<bool> delete(RadioStation station) => _try(
        () => _ref.read(apiProvider).deleteRadioStation(station.id),
        'Removed "${station.name}".',
      );
}

final radioActionsProvider = Provider<RadioActions>(RadioActions.new);
