import 'package:flutter/material.dart';

class Responsive {
  static int gridCount(BuildContext ctx, {int phone = 2, int tablet = 3, int desktop = 4}) {
    final w = MediaQuery.of(ctx).size.width;
    if (w >= 900) return desktop;
    if (w >= 600) return tablet;
    return phone;
  }
  static double horizontalPadding(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    if (w >= 900) return 32;
    if (w >= 600) return 24;
    return 16;
  }
  static bool isTablet(BuildContext ctx) => MediaQuery.of(ctx).size.width >= 600;
}

extension ResponsiveContext on BuildContext {
  int get gridCount => Responsive.gridCount(this);
  double get hPadding => Responsive.horizontalPadding(this);
}
