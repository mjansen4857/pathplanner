import 'package:undo/undo.dart';

class UndoRedo {
  static ChangeStack stack = ChangeStack();

  static void addChange(Change change) {
    stack.add(change);
  }

  static void addChanges(List<Change> changes) {
    stack.addGroup(changes);
  }

  static void undo() {
    stack.undo();
  }

  static void redo() {
    stack.redo();
  }

  static void clearHistory() {
    stack.clearHistory();
  }
}
