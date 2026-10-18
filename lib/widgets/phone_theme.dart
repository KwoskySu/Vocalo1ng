import 'package:flutter/material.dart';

bool isPhoneLayout(BuildContext context) {
  final platform = Theme.of(context).platform;
  return (platform == TargetPlatform.android ||
          platform == TargetPlatform.iOS) &&
      MediaQuery.sizeOf(context).shortestSide < 600;
}

/// Compact visual sizing; keep the user's system text scaler intact.
ThemeData phoneTheme(ThemeData base) => base.copyWith(
  visualDensity: VisualDensity.compact,
  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textTheme: base.textTheme.copyWith(
    bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 14),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 13),
    bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 11),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: 18),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 15),
    titleSmall: base.textTheme.titleSmall?.copyWith(fontSize: 13),
    labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 12),
  ),
  iconTheme: base.iconTheme.copyWith(size: 21),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      minimumSize: const Size(40, 40),
      padding: const EdgeInsets.all(8),
      iconSize: 21,
    ),
  ),
  inputDecorationTheme: base.inputDecorationTheme.copyWith(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: base.filledButtonTheme.style?.copyWith(
      minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: base.outlinedButtonTheme.style?.copyWith(
      minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
  ),
  chipTheme: base.chipTheme.copyWith(
    labelStyle: base.textTheme.labelLarge?.copyWith(fontSize: 12),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    labelPadding: const EdgeInsets.symmetric(horizontal: 5),
  ),
  listTileTheme: base.listTileTheme.copyWith(
    dense: true,
    minVerticalPadding: 6,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
  ),
  sliderTheme: base.sliderTheme.copyWith(
    trackHeight: 2,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
  ),
  navigationBarTheme: base.navigationBarTheme.copyWith(
    labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 10)),
    iconTheme: const WidgetStatePropertyAll(IconThemeData(size: 21)),
  ),
);
