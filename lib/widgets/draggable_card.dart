import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// This could be a stateless widget but the GestureDetector won't work properly
class DraggableCard extends StatefulWidget {
  final Widget? child;
  final double width;
  final CardPosition defaultPosition;
  final String? prefsKey;
  final GlobalKey stackKey;

  DraggableCard(this.stackKey,
      {this.child,
      this.width = 250,
      this.defaultPosition = const CardPosition(),
      this.prefsKey,
      Key? key})
      : super(key: key);

  @override
  State<DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<DraggableCard> {
  Offset? _dragStartLocal;
  GlobalKey _key = GlobalKey();
  CardPosition? _cardPosition;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();

    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      if (widget.prefsKey != null) {
        String? cardJson = _prefs!.getString(widget.prefsKey!);

        if (cardJson != null) {
          setState(() {
            _cardPosition = CardPosition.fromJson(jsonDecode(cardJson));
          });
        } else {
          setState(() {
            _cardPosition = widget.defaultPosition;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cardPosition == null) {
      return Container();
    }

    return Positioned(
      top: _cardPosition!.top,
      left: _cardPosition!.left,
      right: _cardPosition!.right,
      bottom: _cardPosition!.bottom,
      child: GestureDetector(
        key: _key,
        onPanStart: (DragStartDetails details) {
          _dragStartLocal = details.localPosition;
        },
        onPanEnd: (DragEndDetails details) {
          _dragStartLocal = null;
          if (_prefs != null && widget.prefsKey != null) {
            _prefs!.setString(widget.prefsKey!, jsonEncode(_cardPosition));
          }
        },
        onPanUpdate: (DragUpdateDetails details) {
          if (_dragStartLocal != null) {
            RenderBox cardRenderBox =
                _key.currentContext?.findRenderObject() as RenderBox;
            Offset newGlobalPos = details.globalPosition - _dragStartLocal!;
            Size cardSize = cardRenderBox.size;

            RenderBox stackRenderBox =
                widget.stackKey.currentContext?.findRenderObject() as RenderBox;
            Offset newLocalPos = stackRenderBox.globalToLocal(newGlobalPos);
            Size stackSize = stackRenderBox.size;

            bool isTop =
                newLocalPos.dy < (stackSize.height / 2) - (cardSize.height / 2);
            bool isLeft =
                newLocalPos.dx < (stackSize.width / 2) - (cardSize.width / 2);

            CardPosition newCardPos = CardPosition(
              top: isTop ? max(newLocalPos.dy, 0) : null,
              left: isLeft ? max(newLocalPos.dx, 0) : null,
              right: isLeft
                  ? null
                  : max(stackSize.width - newLocalPos.dx - cardSize.width, 0),
              bottom: isTop
                  ? null
                  : max(stackSize.height - newLocalPos.dy - cardSize.height, 0),
            );

            setState(() {
              _cardPosition = newCardPos;
            });
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
      ),
    );
  }
}

class CardPosition {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  const CardPosition({this.top, this.left, this.right, this.bottom});

  factory CardPosition.fromJson(Map<String, dynamic> parsedJson) {
    return CardPosition(
      top: parsedJson['top'],
      left: parsedJson['left'],
      right: parsedJson['right'],
      bottom: parsedJson['bottom'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'top': top,
      'left': left,
      'right': right,
      'bottom': bottom,
    };
  }
}
