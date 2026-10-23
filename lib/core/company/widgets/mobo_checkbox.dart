import 'package:flutter/material.dart';

import '../../style.dart';

/// Custom animated checkbox with modern appearance.
///
/// Features:
/// - Hover effect (light fill on hover when unchecked)
/// - Smooth color/animation transitions
/// - Adaptive colors for light/dark theme
/// - Fully customizable size and corner radius
/// - Disabled state when `onChanged` is null
class MoboCheckbox extends StatefulWidget {
  final bool value;

  /// Called when the user taps the checkbox.
  /// If `null`, the checkbox is disabled (no interaction).
  final ValueChanged<bool>? onChanged;

  final double size;
  final double radius;

  const MoboCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 22,
    this.radius = 6,
  });

  @override
  State<MoboCheckbox> createState() => _MoboCheckboxState();
}

class _MoboCheckboxState extends State<MoboCheckbox> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final primary = AppStyle.primaryColor;
    final isDisabled = widget.onChanged == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: isDisabled ? null : () => widget.onChanged!(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: isDark ? Colors.white : primary,
              width: 2,
            ),
            color: widget.value
                ? (isDark ? Colors.white : primary)
                : (_hovering
                    ? (isDark ? Colors.white : primary.withOpacity(0.10))
                    : Colors.transparent),
          ),
          child: widget.value
              ? Icon(
                  Icons.check_rounded,
                  size: widget.size * 0.75,
                  color: isDark ? Colors.black : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}
