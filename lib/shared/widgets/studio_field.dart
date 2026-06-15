import 'package:flutter/material.dart';

class StudioField extends StatefulWidget {
  const StudioField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.hintText,
    this.maxLines = 1,
    this.textInputAction,
    this.readOnly = false,
    this.onTap,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final VoidCallback onChanged;
  final String? hintText;
  final int maxLines;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;

  @override
  State<StudioField> createState() => _StudioFieldState();
}

class _StudioFieldState extends State<StudioField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool focused = _focusNode.hasFocus;

    // Adaptive color palette
    final Color inputColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Color focusColor = theme.brightness == Brightness.dark 
        ? theme.colorScheme.primary 
        : const Color(0xFF1A3A6B); // rich primary indigo-navy
    final Color iconColor = focused ? focusColor : (isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B));
    final Color labelColor = focused ? focusColor : (isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B));

    final Color bgColor = isDark
        ? (focused ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.06))
        : (focused ? Colors.white : Colors.white.withValues(alpha: 0.62));

    final Color borderColor = isDark
        ? (focused ? focusColor : Colors.white.withValues(alpha: 0.08))
        : (focused ? focusColor : Colors.white.withValues(alpha: 0.72));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor,
          width: isDark ? 0.5 : 1.0,
        ),
        boxShadow: <BoxShadow>[
          if (focused && !isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        crossAxisAlignment: widget.maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: widget.maxLines > 1 ? 16 : 0),
            child: Icon(
              widget.icon,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              focusNode: _focusNode,
              controller: widget.controller,
              maxLines: widget.maxLines,
              textInputAction: widget.textInputAction,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              textCapitalization: widget.textCapitalization,
              keyboardType: widget.keyboardType,
              onChanged: (_) => widget.onChanged(),
              style: TextStyle(
                color: inputColor,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                labelText: widget.label,
                labelStyle: TextStyle(color: labelColor, fontSize: 14, fontWeight: FontWeight.w500),
                hintText: widget.hintText,
                hintStyle: TextStyle(color: isDark ? const Color(0xFF48484A) : const Color(0xFF9AA3B0)),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
