/// Lenient readers for Subsonic JSON: servers disagree on int vs. string vs.
/// missing, so every reader returns null instead of throwing.
int? asInt(Object? v) => switch (v) {
      int i => i,
      num n => n.round(),
      String s => int.tryParse(s),
      _ => null,
    };

String? asString(Object? v) => switch (v) {
      String s when s.isNotEmpty => s,
      num n => n.toString(),
      _ => null,
    };

DateTime? asDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

Duration asSeconds(Object? v) => Duration(seconds: asInt(v) ?? 0);

/// Some servers return a one-item list as a bare object.
List<Map<String, dynamic>> asObjects(Object? v) => switch (v) {
      List l => [for (final e in l) if (e is Map<String, dynamic>) e],
      Map<String, dynamic> m => [m],
      _ => const [],
    };
