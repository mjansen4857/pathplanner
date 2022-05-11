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

class CustomChange<T> extends Change<T> {
  final T _oldValue;
  final void Function(T oldValue) _customExecute;

  CustomChange(
      this._oldValue, this._customExecute, Function(dynamic oldValue) undo)
      : super(_oldValue, () {}, undo);

  @override
  void execute() {
    _customExecute(_oldValue);
  }
}
