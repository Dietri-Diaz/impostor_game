// lib/widgets/auto_fit_title.dart
import 'package:flutter/material.dart';

/// Título que se reduce para caber en el ancho disponible — nunca desborda
/// ni se corta, sin importar el tamaño del celular. Usa FittedBox sobre una
/// sola línea (o varias si se pasan `maxLines`).
class AutoFitTitle extends StatelessWidget {
  const AutoFitTitle(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: textAlign == TextAlign.center
          ? Alignment.center
          : Alignment.centerLeft,
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        softWrap: maxLines > 1,
        style: style,
      ),
    );
  }
}
