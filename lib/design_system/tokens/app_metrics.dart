import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const BorderRadius sm = BorderRadius.all(Radius.circular(12));
  static const BorderRadius md = BorderRadius.all(Radius.circular(20));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(28));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(36));
  static const BorderRadius full = BorderRadius.all(Radius.circular(999));
}
