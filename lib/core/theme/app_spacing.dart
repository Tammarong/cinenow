import 'package:material_ui/material_ui.dart';

/// 4-pt spacing scale. Use these instead of raw numbers so screens stay
/// rhythmically consistent.
abstract final class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal page gutter.
  static const double gutter = 20;

  /// Minimum interactive size (Material / WCAG guidance).
  static const double touchTarget = 48;

  /// Max width for content on tablets / landscape.
  static const double maxContentWidth = 600;

  static const gap4 = SizedBox(width: xxs, height: xxs);
  static const gap8 = SizedBox(width: xs, height: xs);
  static const gap12 = SizedBox(width: sm, height: sm);
  static const gap16 = SizedBox(width: md, height: md);
  static const gap24 = SizedBox(width: lg, height: lg);
  static const gap32 = SizedBox(width: xl, height: xl);
  static const gap48 = SizedBox(width: xxl, height: xxl);
}

abstract final class Radii {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const xlAll = BorderRadius.all(Radius.circular(xl));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const emphasized = Duration(milliseconds: 600);

  static const curve = Curves.easeOutCubic;
  static const curveEmphasized = Curves.easeOutQuart;
  static const curveBounce = Curves.easeOutBack;
}
