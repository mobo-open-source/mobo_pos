import 'package:flutter/material.dart';

/// A reusable search text field with an optional filter button.
class CustomSearchTextField extends StatefulWidget {
  final TextEditingController controller;
  final bool readOnly;
  final void Function(String)? onChanged;
  final VoidCallback? onFilterTap;
  final String? hintText;

  const CustomSearchTextField({
    super.key,
    required this.controller,
    required this.readOnly,
    this.onChanged,
    this.onFilterTap,
    this.hintText,
  });

  @override
  State<CustomSearchTextField> createState() => _CustomSearchTextFieldState();
}

class _CustomSearchTextFieldState extends State<CustomSearchTextField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void didUpdateWidget(CustomSearchTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChange);
      widget.controller.addListener(_onControllerChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasText = widget.controller.text.isNotEmpty;
    final hasFilter = widget.onFilterTap != null;

    final fieldColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final iconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade500;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final shadow = [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        offset: const Offset(3, 11),
        blurRadius: 8.5,
        spreadRadius: -3,
      ),
    ];

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: fieldColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: shadow,
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search_rounded, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    readOnly: widget.readOnly,
                    cursorColor: Theme.of(context).primaryColor,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: widget.hintText ?? 'Search by name',
                      hintStyle: TextStyle(
                        color: iconColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      suffixIcon: hasText
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: iconColor,
                              ),
                              onPressed: () {
                                widget.controller.clear();
                                widget.onChanged?.call('');
                              },
                            )
                          : null,
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    onChanged: widget.onChanged,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        if (hasFilter) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.readOnly ? null : widget.onFilterTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: shadow,
              ),
              child: Icon(
                Icons.filter_alt_rounded,
                color: textColor,
                size: 20,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
