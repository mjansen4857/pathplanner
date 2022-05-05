import 'dart:ui';

import 'package:flutter/material.dart';

// This could be a stateless widget but the GestureDetector won't work properly
class DraggableCard extends StatefulWidget {
  final Widget? child;
  final void Function(Offset, Size)? onDragged;
  final VoidCallback? onDragFinished;
  final double width;

  DraggableCard(
      {this.child,
      this.onDragged,
      this.onDragFinished,
      this.width = 250,
      Key? key})
      : super(key: key);

  @override
  State<DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<DraggableCard> {
  Offset? _dragStartLocal;
  GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _key,
      onPanStart: (DragStartDetails details) {
        _dragStartLocal = details.localPosition;
      },
      onPanEnd: (DragEndDetails details) {
        _dragStartLocal = null;
        if (widget.onDragFinished != null) {
          widget.onDragFinished!.call();
        }
      },
      onPanUpdate: (DragUpdateDetails details) {
        if (widget.onDragged != null && _dragStartLocal != null) {
          RenderBox renderBox =
              _key.currentContext?.findRenderObject() as RenderBox;
          widget.onDragged!
              .call(details.globalPosition - _dragStartLocal!, renderBox.size);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          width: widget.width,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            color: Colors.white.withOpacity(0.13),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
