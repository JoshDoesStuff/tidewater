// Compares plain Text with the animated glyph-by-glyph title for kerning.
// Run: flutter run -d windows -t tool/probes/kern_probe.dart  (stays open for a screenshot)

import 'package:flutter/material.dart';
import 'package:tidewater/app/theme/app_theme.dart';
import 'package:tidewater/ui/widgets/effects/letter_reveal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const title = 'RondeauX of RagnaroQ -Crescendo of Cataclysm- blue flavor Xeon ett';
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(Brightness.dark),
    home: Scaffold(
      body: RepaintBoundary(
        child: Container(
          color: const Color(0xFF3A2A30),
          padding: const EdgeInsets.all(20),
          alignment: Alignment.topLeft,
          child: Builder(
            builder: (context) {
              final style = Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 32, fontWeight: FontWeight.w700);
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: style),
                const SizedBox(height: 16),
                LetterReveal(text: title, style: style),
              ]);
            },
          ),
        ),
      ),
    ),
  ));
  // Stays open so it can be screenshotted.
}
