import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Hides the keyboard when the user taps outside the focused field
/// or starts scrolling any list.
class KeyboardDismiss extends StatelessWidget {
  const KeyboardDismiss({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
        return false;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _unfocusIfOutsideField,
        child: child,
      ),
    );
  }

  static void _unfocusIfOutsideField(PointerDownEvent event) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || !focus.hasFocus) return;
    final ctx = focus.context;
    if (ctx == null) {
      focus.unfocus();
      return;
    }
    final box = ctx.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final local = box.globalToLocal(event.position);
      // Inflate so dragging the cursor handle does not dismiss.
      if (box.paintBounds.inflate(32).contains(local)) return;
    }
    focus.unfocus();
  }
}
