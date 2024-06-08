import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:function_tree/function_tree.dart';
import 'package:intl/intl.dart';

class NumberTextField extends StatefulWidget {
  final num value;
  final String label;
  final ValueChanged<num> onSubmitted;
  final int displayPrecision;
  final double height;
  final bool enabled;
  final num arrowKeyIncrement;
  final num minValue;
  final num maxValue;

  const NumberTextField(
      {super.key,
      required this.value,
      required this.label,
      required this.onSubmitted,
      this.displayPrecision = 3,
      this.height = 42,
      this.enabled = true,
      this.arrowKeyIncrement = 0.05,
      this.minValue = double.negativeInfinity,
      this.maxValue = double.infinity});

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
    _setControllerText();

    _focusNode.addListener(() {
      bool isFocused = _focusNode.hasPrimaryFocus;
      // Component gained focus
      if (!_isEditing && isFocused) {
        _controller.selection =
            TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      }
      // Component lost focus
      else if (_isEditing && !isFocused) {
        _handleExpressionSubmit(_controller.text);
      }
      setState(() {
        _isEditing = isFocused;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(NumberTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _setControllerText();
    }
  }

  @override
  Widget build(BuildContext context) {
    TextField textField = TextField(
      enabled: widget.enabled,
      controller: _controller,
      focusNode: _focusNode,
      onSubmitted: _handleExpressionSubmit,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
            // Matches basic expressions like 3 + 5, 4 * 2 + 6, etc.
            RegExp(r'(^(-?)\d*\.?\d*)([+/\*\-](-?)\d*\.?\d*)*')),
      ],
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        labelText: widget.label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    return SizedBox(
      height: widget.height,
      child: CallbackShortcuts(bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          _handleIncrement(_controller.text);
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          _handleDecrement(_controller.text);
        },
      }, child: textField),
    );
  }

  /// Sets the controller's text based on the current value.
  void _setControllerText() {
    // Format number for display
    NumberFormat formatter = NumberFormat();
    formatter.minimumFractionDigits = 0;
    formatter.maximumFractionDigits = widget.displayPrecision;
    _controller.value =
        _controller.value.copyWith(text: formatter.format(widget.value));
  }

  /// Parses an expression entered by the user. Returns null if the expression is invalid.
  num? _parse(String expression) {
    if (expression.isEmpty) {
      return null;
    }
    try {
      return expression.interpret();
    } catch (_) {
      return null;
    }
  }

  /// Handles the submission of an expression.
  void _handleExpressionSubmit(String expression) {
    num? parsed = _parse(expression);
    if (parsed == null) {
      return;
    }
    _handleSubmit(parsed);
  }

  /// Handles the submission of a value.
  void _handleSubmit(num value) {
    if (value > widget.maxValue) {
      return;
    }
    if (value < widget.minValue) {
      return;
    }
    // == okay since we only care about debouncing exact repetition
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
    // Even though _lastSubmitted is guaranteed to be different from value at this point,
    // We still need to update _lastSubmitted so we don't debounce a real update
    _handleSubmit(parsed + widget.arrowKeyIncrement);
  }

  void _handleDecrement(String expression) {
    num? parsed = _parse(expression);
    if (parsed == null) {
      return;
    }
    _handleSubmit(parsed - widget.arrowKeyIncrement);
  }
}
