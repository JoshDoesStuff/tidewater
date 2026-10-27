import 'package:flutter/material.dart';

/// The theme the app is recoloring towards, without the in-between steps.
///
/// `Theme.of` changes on every frame of the ~800 ms recolor after a track change, so everything
/// that reads it builds again sixty-plus times. A page of album cards doing that (and dropping
/// the pictures they rest as) was 30-65 ms of work per frame for most of a second. Widgets that
/// are many to a page and only use a few colors read this instead: they change once, at the
/// start of the recolor.
class SettledTheme extends InheritedWidget {
  const SettledTheme({super.key, required this.data, required super.child});

  final ThemeData data;

  /// The settled theme, or the current one where there is none (tests, dialogs built outside).
  static ThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettledTheme>()?.data ?? Theme.of(context);

  @override
  bool updateShouldNotify(SettledTheme old) => data != old.data;
}
