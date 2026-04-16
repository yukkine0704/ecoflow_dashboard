import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

extension ThemeContext on BuildContext {
  AppColors get appColors {
    final colors = Theme.of(this).extension<AppColors>();
    assert(colors != null, 'AppColors extension missing from ThemeData.');
    return colors!;
  }
}
