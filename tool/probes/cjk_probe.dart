// Shows Latin, Japanese and Chinese titles with the app theme, to check the
// font fallback by eye. It stays open so it can be screenshotted.
// Run: flutter run -d windows -t tool/probes/cjk_probe.dart
import 'package:flutter/material.dart';
import 'package:tidewater/app/theme/app_theme.dart';
import 'package:tidewater/ui/widgets/name_text.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const lines = [
    'Monster Siren Records',
    '危机合约 黄铁·利刃',
    '塞壬唱片-MSR 明日方舟 音律联觉',
    'ハローセカイ / バーチャル・シンガー',
    '初音ミク × 鏡音リン × 鏡音レン',
    '怪獣になりたい 黒魔 八王子P',
    '这是一首歌 直 骨 海 返 角 刃',
  ];
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Builder(
          builder: (context) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final l in lines) ...[
                NameText(l, style: Theme.of(context).textTheme.headlineMedium),
                NameText(l, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
