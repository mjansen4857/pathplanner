import 'package:file/memory.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/pages/path2_editor_page.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/widgets/editor/split_path2_editor.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

void main() {
  late path2.Path path;
  late ChangeStack undoStack;
  late SharedPreferences prefs;
  String? renamedTo;

  setUp(() async {
    path = path2.Path.defaultPath(
      name: 'Path2',
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );
    undoStack = ChangeStack();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    renamedTo = null;
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    await tester.pumpWidget(
      MaterialApp(
        home: Path2EditorPage(
          prefs: prefs,
          path: path,
          fieldImage: FieldImage.defaultField,
          onRenamed: (name) => renamedTo = name,
          undoStack: undoStack,
          shortcuts: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the Path2 editor', (tester) async {
    await pumpPage(tester);
    expect(find.byType(SplitPath2Editor), findsOneWidget);
  });

  testWidgets('renames through the app bar title', (tester) async {
    await pumpPage(tester);

    final title = find.byType(RenamableTitle);
    await tester.enterText(title, 'Renamed Path2');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(renamedTo, 'Renamed Path2');
  });

  testWidgets('back clears the editor undo history', (tester) async {
    await pumpPage(tester);
    undoStack.add(Change<void>(null, () {}, (_) {}));
    expect(undoStack.canUndo, isTrue);

    await tester.tap(find.byType(BackButton));
    await tester.pump();

    expect(undoStack.canUndo, isFalse);
  });
}
