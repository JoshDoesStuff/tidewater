import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Text for the user's music (track, album, artist and playlist names, lyrics):
/// a [Text] that picks the Japanese or the Chinese typeface first, depending on
/// the string, so Han characters are drawn the right way.
class NameText extends StatelessWidget {
  const NameText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTheme.script(text, style),
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        softWrap: softWrap,
      );
}
