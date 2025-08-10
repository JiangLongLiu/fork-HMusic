import 'package:flutter/material.dart';

/// Shared layout utilities related to the floating bottom navigation overlay.
class AppLayout {
  const AppLayout._();

  /// Total vertical space occupied by the floating bottom navigation overlay,
  /// including its top margin and bottom safe-area margin.
  static double bottomOverlayHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom; // home indicator, etc.
    final hasBottomInset = bottomInset > 0;

    const double navHeight = 68.0; // matches _buildModernBottomNav
    const double navTopMargin = 10.0;
    final double navBottomMargin = hasBottomInset ? (bottomInset + 8.0) : 20.0;

    return navHeight + navTopMargin + navBottomMargin;
  }

  /// Suggested content bottom padding so the last item scrolls above the nav.
  static double contentBottomPadding(
    BuildContext context, {
    double extra = 12,
  }) {
    return bottomOverlayHeight(context) + extra;
  }
}
