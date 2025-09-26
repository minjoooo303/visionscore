import 'package:flutter/material.dart';

/// 오른쪽 → 왼쪽으로 미는 전환 효과
class SlideFromRightPageRoute<T> extends PageRouteBuilder<T> {
  SlideFromRightPageRoute({required WidgetBuilder builder})
      : super(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
