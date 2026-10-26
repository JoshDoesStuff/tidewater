import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the queue was last saved, for Settings to show (so you can tell it
/// reached the server, or why it went to this PC instead).
enum QueueHome { none, server, thisPc }

class QueueSyncStatus {
  const QueueSyncStatus(this.home, {this.at, this.songs = 0, this.position = Duration.zero, this.reason});

  final QueueHome home;
  final DateTime? at;
  final int songs;

  /// Where in the current song the saved position was.
  final Duration position;

  /// Why it is on this PC: syncing is off, or what went wrong with the server.
  final String? reason;
}

class QueueSyncStatusNotifier extends Notifier<QueueSyncStatus> {
  @override
  QueueSyncStatus build() => const QueueSyncStatus(QueueHome.none);

  void set(QueueSyncStatus value) => state = value;
}

final queueSyncStatusProvider = NotifierProvider<QueueSyncStatusNotifier, QueueSyncStatus>(QueueSyncStatusNotifier.new);
