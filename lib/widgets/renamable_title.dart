import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RenamableTitle extends StatefulWidget {
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
  State<RenamableTitle> createState() => _RenameableTitleState();
}

class _RenameableTitleState extends State<RenamableTitle> {
  bool _isEditing = false;
  String? _lastSubmitted;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.title;
    _focusNode.addListener(() {
      bool isFocused = _focusNode.hasPrimaryFocus;
      // Component gained focus
      if (!_isEditing && isFocused) {
        _controller.selection =
            TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      }
      // Component lost focus
      else if (_isEditing && !isFocused) {
        _handleSubmit(_controller.text);
      }
      setState(() {
        _isEditing = isFocused;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RenamableTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      _controller.value = _controller.value.copyWith(text: widget.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    InputDecoration decoration = InputDecoration(
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
      contentPadding: widget.contentPadding ??
          const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    );

    return IntrinsicWidth(
      child: TextField(
        focusNode: _focusNode,
        controller: _controller,
        onSubmitted: _handleSubmit,
        style: widget.textStyle ?? TextStyle(color: colorScheme.onSurface),
        decoration: decoration,
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp('["*<>?|/:\\\\]')),
        ],
      ),
    );
  }

  void _handleSubmit(String text) {
    if (text.isEmpty) {
      return;
    } else if (_lastSubmitted == text) {
      return;
    }
    _lastSubmitted = text;
    widget.onRename?.call(text);
  }
}
