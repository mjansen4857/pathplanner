import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MarkerEditor extends StatefulWidget {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;
  final void Function(RobotPath path)? savePath;
  final SharedPreferences? prefs;

  const MarkerEditor(
      this.path, this.fieldImage, this.robotSize, this.holonomicMode,
      {this.savePath, this.prefs, Key? key})
      : super(key: key);

  @override
  State<MarkerEditor> createState() => _MarkerEditorState();
}

class _MarkerEditorState extends State<MarkerEditor> {
  GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _key,
      children: [
        Center(
          child: InteractiveViewer(
            child: GestureDetector(
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Stack(
                    children: [
                      widget.fieldImage,
                      Positioned.fill(
                        child: Container(
                          child: CustomPaint(
                            painter: _MarkerPainter(
                              widget.path,
                              widget.fieldImage,
                              widget.robotSize,
                              widget.holonomicMode,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final RobotPath path;
  final FieldImage fieldImage;
  final Size robotSize;
  final bool holonomicMode;

  _MarkerPainter(
      this.path, this.fieldImage, this.robotSize, this.holonomicMode);

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: implement paint
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
