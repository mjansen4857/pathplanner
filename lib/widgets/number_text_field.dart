import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:function_tree/function_tree.dart';
import 'package:pathplanner/services/log.dart';
import 'package:intl/intl.dart';

class NumberTextField extends StatefulWidget {
  final num value;
  final String label;
  final double height;
  final bool enabled;
  final ValueChanged<num> onSubmitted;
  final num arrowKeyIncrement;

  const NumberTextField({
    super.key,
    required this.value,
    required this.label,
    this.height = 42,
    required this.onSubmitted,
    this.enabled = true,
    this.arrowKeyIncrement = 0.05,
  });

  @override
  State<NumberTextField> createState() => _NumberTextFieldState();
}

class _NumberTextFieldState extends State<NumberTextField> {
  bool _isEditing = false;
  num? _lastSubmitted;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      bool isFocused = _focusNode.hasPrimaryFocus;
      Log.debug("Debug changed. Has primary focus?: $isFocused");
      Log.debug(_focusNode.hasFocus);
      setState(() {
        _isEditing = isFocused;
      });
      if (!_isEditing) {
        _handleExpressionSubmit(_controller.text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    NumberFormat formatter = NumberFormat();
    formatter.minimumFractionDigits = 0;
    if (_isEditing) {
      // display with extra precision
      formatter.maximumFractionDigits = 3;
    } else {
      formatter.maximumFractionDigits = 2;
    }
    _controller.text = formatter.format(widget.value);

    return SizedBox(
      height: widget.height,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): () {
            _handleIncrement(_controller.text);
          },
          const SingleActivator(LogicalKeyboardKey.arrowDown): () {
            _handleDecrement(_controller.text);
          },
        },
        child: TextField(
          enabled: widget.enabled,
          controller: _controller,
          focusNode: _focusNode,
          onSubmitted: _handleExpressionSubmit,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'(^(-?)\d*\.?\d*)([+/\*\-](-?)\d*\.?\d*)*')),
          ],
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            labelText: widget.label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  num? _parse(String expression) {
    try {
      return expression.interpret();
    } catch (_) {
      return null;
    }
  }

  void _handleExpressionSubmit(String expression) {
    num? parsed = _parse(expression);
    if (parsed == null) {
      return;
    }
    _handleSubmit(parsed);
  }

  void _handleSubmit(num value) {
    // We only care about debouncing exact repetition
    if (_lastSubmitted == value) {
      return;
    }
    _lastSubmitted = value;
    widget.onSubmitted(value);
  }

  void _handleIncrement(String expression) {
    num? parsed = _parse(expression);
    if (parsed == null) {
      return;
    }
    // Even though _lastSubmitted is guaranteed to be different from value,
    // We still need to update _lastSubmitted so we don't debounce the wrong thing
    _handleSubmit(parsed + widget.arrowKeyIncrement);
  }

  void _handleDecrement(String expression) {
    num? parsed = _parse(expression);
    if (parsed == null) {
      return;
    }
    _handleSubmit(parsed - widget.arrowKeyIncrement);
    // if (val.isNotEmpty) {
    //   num parsed = val.interpret();

    //   // Doing this dumb thing cuz dart modulo has insane floating point errors
    //   num n = (parsed / arrowKeyIncrement).round() * arrowKeyIncrement;
    //   num remainder = parsed - n;

    //   if (remainder.abs() > 1E-3) {
    //     if (remainder < 0) {
    //       onSubmitted?.call(parsed - (arrowKeyIncrement - remainder.abs()));
    //     } else {
    //       onSubmitted?.call(parsed - remainder.abs());
    //     }
    //   } else {
    //     onSubmitted?.call(parsed - arrowKeyIncrement);
    //   }
    // }
  }
}
