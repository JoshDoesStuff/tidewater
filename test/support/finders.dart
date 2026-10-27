import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/ui/widgets/hint.dart';

/// The control whose hover label (a [Hint]) says [message].
Finder byHint(String message) => find.byWidgetPredicate((w) => w is Hint && w.message == message, description: 'hint "$message"');
