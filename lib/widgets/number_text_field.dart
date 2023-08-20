import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:function_tree/function_tree.dart';

class NumberTextField extends StatelessWidget {
  final String initialText;
  final String label;
  final double height;
  final bool enabled;
  final ValueChanged<num?>? onSubmitted;
  final num arrowKeyIncrement;

  late final TextEditingController _controller;

  NumberTextField({
    super.key,
    required this.initialText,
    required this.label,
    this.height = 42,
    this.onSubmitted,
    this.enabled = true,
    this.arrowKeyIncrement = 0.01,
  }) {
    _controller = _getController(initialText);
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: height,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): () {
            _submitIncrement(_controller.text);
          },
          const SingleActivator(LogicalKeyboardKey.arrowDown): () {
            _submitDecrement(_controller.text);
          },
        },
        child: Focus(
          skipTraversal: true,
          onFocusChange: (hasFocus) {
            if (!hasFocus) {
              _onSubmitted(_controller.text);
            }
          },
          child: TextField(
            enabled: enabled,
            controller: _controller,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'(^(-?)\d*\.?\d*)([+/\*\-](-?)\d*\.?\d*)*')),
            ],
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              labelText: label,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
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

  void _submitIncrement(String val) {
    if (val.isNotEmpty) {
      num parsed = val.interpret();
      onSubmitted?.call(parsed + arrowKeyIncrement);
    }
  }

  void _submitDecrement(String val) {
    if (val.isNotEmpty) {
      num parsed = val.interpret();
      onSubmitted?.call(parsed - arrowKeyIncrement);
    }
  }

  TextEditingController _getController(String text) {
    return TextEditingController(text: text)
      ..selection =
          TextSelection.fromPosition(TextPosition(offset: text.length));
  }
}
