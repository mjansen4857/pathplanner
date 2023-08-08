import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RenamableTitle extends StatelessWidget {
  final String title;
  final ValueChanged<String>? onRename;
  final TextStyle? textStyle;
  final EdgeInsets? contentPadding;

  const RenamableTitle({
    super.key,
    required this.title,
    this.onRename,
    this.textStyle,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return IntrinsicWidth(
      child: TextField(
        onSubmitted: (String text) {
          if (text.isNotEmpty) {
            FocusScopeNode currentScope = FocusScope.of(context);
            if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
              FocusManager.instance.primaryFocus!.unfocus();
            }
            onRename?.call(text);
          }
        },
        style: textStyle ?? TextStyle(color: colorScheme.onSurface),
        controller: TextEditingController(text: title)
          ..selection =
              TextSelection.fromPosition(TextPosition(offset: title.length)),
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: colorScheme.outline,
            ),
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.transparent,
            ),
          ),
          contentPadding: contentPadding ??
              const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp('["*<>?|/:\\\\]')),
        ],
      ),
    );
  }
}
