import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:function_tree/function_tree.dart';

class NumberTextField extends StatelessWidget {
  final String initialText;
  final String label;
  final double height;
  final bool enabled;
  final ValueChanged<num?>? onSubmitted;

  late final TextEditingController _controller;

  NumberTextField({
    super.key,
    required this.initialText,
    required this.label,
    this.height = 42,
    this.onSubmitted,
    this.enabled = true,
  }) {
    _controller = _getController(initialText);
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: height,
      child: Focus(
        skipTraversal: true,
        onFocusChange: (hasFocus) {
          if (!hasFocus) {
            _onSubmitted(_controller.text);
          }
        },
        child: TextField(
          enabled: enabled,
          onSubmitted: _onSubmitted,
          controller: _controller,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'(^(-?)\d*\.?\d*)([+/\*\-](-?)\d*\.?\d*)*')),
          ],
          style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  void _onSubmitted(String val) {
    if (val.isEmpty) {
      onSubmitted?.call(null);
    } else {
      num parsed = val.interpret();
      onSubmitted?.call(parsed);
    }
  }

  TextEditingController _getController(String text) {
    return TextEditingController(text: text)
      ..selection =
          TextSelection.fromPosition(TextPosition(offset: text.length));
  }
}
