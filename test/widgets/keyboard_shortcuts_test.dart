import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';

void main() {
  test('settings shortcut maps to Control+Comma on non-macOS', () {
    if (Platform.isMacOS) {
      return;
    }

    expect(
      shortCut(BasicShortCuts.settings),
      {LogicalKeyboardKey.control, LogicalKeyboardKey.comma},
    );
  });

  test('settings shortcut maps to Meta+Comma on macOS', () {
    if (!Platform.isMacOS) {
      return;
    }

    expect(
      shortCut(BasicShortCuts.settings),
      {LogicalKeyboardKey.meta, LogicalKeyboardKey.comma},
    );
  });

  test('settings shortcut requires a modifier, not a plain comma', () {
    final keys = shortCut(BasicShortCuts.settings);

    expect(keys, contains(LogicalKeyboardKey.comma));
    expect(keys.length, 2);
    expect(keys, isNot({LogicalKeyboardKey.comma}));
  });

  test('existing shortcuts remain unchanged', () {
    if (Platform.isMacOS) {
      expect(
        shortCut(BasicShortCuts.undo),
        {LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ},
      );
      expect(
        shortCut(BasicShortCuts.redo),
        {LogicalKeyboardKey.meta, LogicalKeyboardKey.keyY},
      );
    } else {
      expect(
        shortCut(BasicShortCuts.undo),
        {LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ},
      );
      expect(
        shortCut(BasicShortCuts.redo),
        {LogicalKeyboardKey.control, LogicalKeyboardKey.keyY},
      );
    }

    expect(
      shortCut(BasicShortCuts.save),
      {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyS},
    );
  });
}
