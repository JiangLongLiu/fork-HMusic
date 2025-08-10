import 'package:flutter/material.dart';

/// Centralized helper to show SnackBars above the bottom navigation bar
/// so they do not overlap it.
class AppSnackBar {
  const AppSnackBar._();

  /// Computes a bottom margin that safely clears the custom bottom navigation.
  /// Matches measurements defined in `MainPage._buildModernBottomNav`.
  static double _computeBottomMargin(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom; // iOS home indicator etc.
    final hasBottomInset = bottomInset > 0;

    const double navHeight = 68.0; // height of the navbar container
    const double navTopMargin = 10.0; // top margin above navbar
    final double navBottomMargin = hasBottomInset ? (bottomInset + 8.0) : 20.0;

    // Leave an extra gap above the navbar for visual separation.
    const double extraGap = 12.0;

    return navHeight + navTopMargin + navBottomMargin + extraGap;
  }

  /// Show a SnackBar ensuring it appears above the bottom navigation.
  static void show(BuildContext context, SnackBar base) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final margin = EdgeInsets.fromLTRB(
      16,
      0,
      16,
      _computeBottomMargin(context),
    );

    // Rebuild a SnackBar that forces floating behavior and safe bottom margin.
    final snackBar = SnackBar(
      content: base.content,
      action: base.action,
      backgroundColor: base.backgroundColor,
      duration: base.duration,
      elevation: base.elevation,
      shape: base.shape,
      padding: base.padding,
      behavior: SnackBarBehavior.floating,
      margin: margin,
    );

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(snackBar);
  }

  /// Convenience for simple text messages.
  static void showText(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context,
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
  }
}
