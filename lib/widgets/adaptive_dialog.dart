import 'package:flutter/material.dart';

/// Common bounds for editor, login, list and settings dialogs on phones.
class AdaptiveDialog extends StatelessWidget {
  const AdaptiveDialog({
    super.key,
    required this.child,
    this.insetPadding,
    this.backgroundColor,
    this.shape,
    this.clipBehavior = Clip.none,
  });
  final Widget child;
  final EdgeInsets? insetPadding;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final Clip clipBehavior;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.shortestSide < 600;
    return Dialog(
      insetPadding: compact
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
          : insetPadding,
      backgroundColor: backgroundColor,
      shape: shape,
      clipBehavior: clipBehavior,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width - (compact ? 20 : 80),
          maxHeight:
              (size.height -
                      MediaQuery.viewInsetsOf(context).bottom -
                      MediaQuery.paddingOf(context).vertical -
                      (compact ? 20 : 48))
                  .clamp(80, 1200),
        ),
        child: child,
      ),
    );
  }
}
