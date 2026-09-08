import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file/memory.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/simulation/simulation_state.dart';
import 'package:pathplanner/path2/waypoint.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/editor/path2_painter.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FieldImage fieldImage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.showGrid: false,
      PrefsKeys.robotWidth: 0.8,
      PrefsKeys.robotLength: 0.8,
      PrefsKeys.bumperOffsetX: 0.0,
      PrefsKeys.bumperOffsetY: 0.0,
      PrefsKeys.flModuleX: 0.25,
      PrefsKeys.flModuleY: 0.25,
      PrefsKeys.frModuleX: 0.25,
      PrefsKeys.frModuleY: -0.25,
      PrefsKeys.blModuleX: -0.25,
      PrefsKeys.blModuleY: 0.25,
      PrefsKeys.brModuleX: -0.25,
      PrefsKeys.brModuleY: -0.25,
    });
    prefs = await SharedPreferences.getInstance();
    fieldImage = FieldImage.official(OfficialField.chargedUp);
  });

  path2.Path makePath({
    List<path2.PathNode>? nodes,
    List<path2.PathBranch>? branches,
  }) {
    return path2.Path(
      name: 'render',
      nodes:
          nodes ??
          [
            path2.PathNode(
              id: 'a',
              waypoint: TranslationWaypoint(
                position: const Translation2d(1, 4),
              ),
              editorPosition: const Offset(0, 0),
            ),
            path2.PathNode(
              id: 'b',
              waypoint: TranslationWaypoint(
                position: const Translation2d(4, 4),
              ),
              editorPosition: const Offset(0, 200),
            ),
          ],
      branches:
          branches ??
          [path2.PathBranch(id: 'ab', sourceId: 'a', targetId: 'b')],
      fs: MemoryFileSystem(),
      pathDir: '/paths',
    );
  }

  Path2Painter painter(
    path2.Path path, {
    Set<String>? visibleNodeIds,
    bool simple = false,
    String? selectedNodeId,
    List<Path2SimulationResult> simulations = const [],
  }) {
    return Path2Painter(
      colorScheme: const ColorScheme.light(),
      paintPaths: [Path2PaintPath(path: path, visibleNodeIds: visibleNodeIds)],
      fieldImage: fieldImage,
      prefs: prefs,
      simple: simple,
      selectedNodeId: selectedNodeId,
      showWaypointRobotPreviews: false,
      simulations: simulations,
      simulationDurationSeconds: 1,
    );
  }

  test('event diamonds are anchored at the recorded robot pose', () async {
    final path = makePath();
    const pose = Pose2d(Translation2d(2, 3), Rotation2d());
    final samples = [
      Path2SimulationSample(
        timeSeconds: 0,
        state: Path2SimulationState.atRest(pose),
      ),
    ];
    final before = await _render(
      painter(
        path,
        simple: true,
        simulations: [Path2SimulationResult(samples)],
      ),
    );
    final after = await _render(
      painter(
        path,
        simple: true,
        simulations: [
          Path2SimulationResult(
            samples,
            branchEventMarkers: [
              const Path2BranchEventMarker(
                branchId: 'ab',
                eventIndex: 0,
                name: 'Intake',
                timeSeconds: 0,
                pose: pose,
              ),
              const Path2BranchEventMarker(
                branchId: 'ab',
                eventIndex: 1,
                name: 'Score',
                timeSeconds: 0,
                pose: pose,
              ),
            ],
          ),
        ],
      ),
    );
    final point = PathPainterUtil.pointToPixelOffset(
      pose.translation,
      Path2Painter.scale,
      fieldImage,
    );
    expect(_hasDifferenceNear(before, after, point, radius: 9), isTrue);
    expect(
      _containsColorNear(
        after,
        point,
        _rgba(const ColorScheme.light().tertiary),
        5,
      ),
      isTrue,
    );
  });

  test('renders only branches and nodes in the visible ancestor set', () async {
    final a = path2.PathNode(
      id: 'a',
      waypoint: TranslationWaypoint(position: const Translation2d(1, 4)),
      editorPosition: Offset.zero,
    );
    final b = path2.PathNode(
      id: 'b',
      waypoint: TranslationWaypoint(position: const Translation2d(4, 4)),
      editorPosition: const Offset(0, 200),
    );
    final c = path2.PathNode(
      id: 'c',
      waypoint: TranslationWaypoint(position: const Translation2d(7, 4)),
      editorPosition: const Offset(0, 400),
    );
    final path = makePath(
      nodes: [a, b, c],
      branches: [
        path2.PathBranch(id: 'ab', sourceId: 'a', targetId: 'b'),
        path2.PathBranch(id: 'bc', sourceId: 'b', targetId: 'c'),
      ],
    );
    final ancestorsOnly = await _render(
      painter(path, visibleNodeIds: {'a', 'b'}),
    );
    final allNodes = await _render(painter(path));
    final hiddenNode = PathPainterUtil.pointToPixelOffset(
      c.waypoint.position,
      Path2Painter.scale,
      fieldImage,
    );
    final hiddenBranchMidpoint = PathPainterUtil.pointToPixelOffset(
      const Translation2d(5.5, 4),
      Path2Painter.scale,
      fieldImage,
    );

    expect(
      _hasDifferenceNear(ancestorsOnly, allNodes, hiddenNode, radius: 18),
      isTrue,
    );
    expect(
      _hasDifferenceNear(
        ancestorsOnly,
        allNodes,
        hiddenBranchMidpoint,
        radius: 8,
      ),
      isTrue,
    );
  });

  test('parallel branches render as separately offset dotted traces', () async {
    final single = makePath();
    final parallel = makePath(
      branches: [
        path2.PathBranch(id: 'one', sourceId: 'a', targetId: 'b'),
        path2.PathBranch(id: 'two', sourceId: 'a', targetId: 'b'),
      ],
    );
    final oneTrace = await _render(painter(single));
    final twoTraces = await _render(painter(parallel));
    final midpoint = PathPainterUtil.pointToPixelOffset(
      const Translation2d(2.5, 4),
      Path2Painter.scale,
      fieldImage,
    );

    expect(
      _hasDifferenceNear(oneTrace, twoTraces, midpoint, radius: 12),
      isTrue,
    );
  });

  test('one-node graph uses combined start and end styling', () async {
    final path = makePath(
      nodes: [
        path2.PathNode(
          id: 'only',
          waypoint: TranslationWaypoint(position: const Translation2d(2, 4)),
          editorPosition: Offset.zero,
        ),
      ],
      branches: [],
    );
    final image = await _render(painter(path));
    final center = PathPainterUtil.pointToPixelOffset(
      const Translation2d(2, 4),
      Path2Painter.scale,
      fieldImage,
    );

    expect(
      _containsColorNear(image, center, const [244, 67, 54, 255], 12),
      isTrue,
    );
    expect(
      _containsColorNear(image, center, const [76, 175, 80, 255], 18),
      isTrue,
    );
  });

  test('non-simple pose nodes show the field heading handle', () async {
    final pose = path2.PathNode(
      id: 'pose',
      waypoint: PoseWaypoint(
        position: const Translation2d(2, 4),
        rotation: const Rotation2d(),
      ),
      editorPosition: Offset.zero,
    );
    final path = makePath(nodes: [pose], branches: []);
    final simple = await _render(painter(path, simple: true));
    final editable = await _render(painter(path));
    final handle = PathPainterUtil.pointToPixelOffset(
      const Translation2d(2.4, 4),
      Path2Painter.scale,
      fieldImage,
    );

    expect(_hasDifferenceNear(simple, editable, handle, radius: 12), isTrue);

    final center = PathPainterUtil.pointToPixelOffset(
      pose.waypoint.position,
      Path2Painter.scale,
      fieldImage,
    );
    final midpoint = Offset.lerp(center, handle, 0.5)!;
    expect(
      _hasDifferenceNear(simple, editable, midpoint, radius: 1),
      isFalse,
      reason: 'the heading control should be a drag dot without a line',
    );
  });

  test(
    'point-towards target renders only for the selected editable node',
    () async {
      final point = path2.PathNode(
        id: 'point',
        waypoint: PointTowardsWaypoint(
          position: const Translation2d(2, 4),
          targetPosition: const Translation2d(4, 2),
        ),
        editorPosition: Offset.zero,
      );
      final path = makePath(nodes: [point], branches: []);
      final unselected = await _render(painter(path));
      final selected = await _render(painter(path, selectedNodeId: point.id));
      final simple = await _render(
        painter(path, simple: true, selectedNodeId: point.id),
      );
      final target = PathPainterUtil.pointToPixelOffset(
        const Translation2d(4, 2),
        Path2Painter.scale,
        fieldImage,
      );

      expect(
        _hasDifferenceNear(unselected, selected, target, radius: 28),
        isTrue,
      );
      expect(
        _hasDifferenceNear(unselected, simple, target, radius: 28),
        isFalse,
      );
      expect(
        _containsColorNear(selected, target, _rgba(Colors.orange), 20),
        isTrue,
      );
    },
  );

  test(
    'all preview traces, robots, and swerve modules use one color',
    () async {
      Path2SimulationResult traversalAt(double y) => Path2SimulationResult([
        Path2SimulationSample(
          timeSeconds: 0,
          state: Path2SimulationState.atRest(
            Pose2d(Translation2d(1, y), const Rotation2d()),
          ),
        ),
        Path2SimulationSample(
          timeSeconds: 1,
          state: Path2SimulationState.atRest(
            Pose2d(Translation2d(3, y), const Rotation2d()),
          ),
        ),
      ]);

      final image = await _render(
        painter(makePath(), simulations: [traversalAt(-2), traversalAt(2)]),
      );
      final primary = const ColorScheme.light().primary;
      final traceColor = primary.withAlpha(150);

      for (final y in [-2.0, 2.0]) {
        final traceMidpoint = PathPainterUtil.pointToPixelOffset(
          Translation2d(2, y),
          Path2Painter.scale,
          fieldImage,
        );
        expect(
          _containsColorNear(image, traceMidpoint, _rgba(traceColor), 4) ||
              _containsColorNear(
                image,
                traceMidpoint,
                _premultipliedRgba(traceColor),
                4,
              ),
          isTrue,
        );
      }

      final frontLeftModule = PathPainterUtil.pointToPixelOffset(
        const Translation2d(1.25, -1.75),
        Path2Painter.scale,
        fieldImage,
      );
      expect(
        _containsColorNear(image, frontLeftModule, _rgba(primary), 8),
        isTrue,
        reason: 'the preview should draw the simulated swerve modules',
      );
    },
  );
}

class _RenderedImage {
  final Uint8List bytes;
  final int width;
  final int height;

  const _RenderedImage(this.bytes, this.width, this.height);
}

Future<_RenderedImage> _render(Path2Painter painter) async {
  const width = 600;
  final height =
      (painter.fieldImage.defaultSize.height /
              painter.fieldImage.defaultSize.width *
              width)
          .round();
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Size(width.toDouble(), height.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  picture.dispose();
  image.dispose();
  return _RenderedImage(data!.buffer.asUint8List(), width, height);
}

bool _hasDifferenceNear(
  _RenderedImage before,
  _RenderedImage after,
  Offset center, {
  required int radius,
}) {
  final minX = (center.dx.floor() - radius).clamp(0, before.width - 1);
  final maxX = (center.dx.ceil() + radius).clamp(0, before.width - 1);
  final minY = (center.dy.floor() - radius).clamp(0, before.height - 1);
  final maxY = (center.dy.ceil() + radius).clamp(0, before.height - 1);
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final offset = (y * before.width + x) * 4;
      for (var channel = 0; channel < 4; channel++) {
        if (before.bytes[offset + channel] != after.bytes[offset + channel]) {
          return true;
        }
      }
    }
  }
  return false;
}

bool _containsColorNear(
  _RenderedImage image,
  Offset center,
  List<int> color,
  int radius,
) {
  for (var yOffset = -radius; yOffset <= radius; yOffset++) {
    for (var xOffset = -radius; xOffset <= radius; xOffset++) {
      final x = (center.dx.round() + xOffset).clamp(0, image.width - 1);
      final y = (center.dy.round() + yOffset).clamp(0, image.height - 1);
      final offset = (y * image.width + x) * 4;
      var matches = true;
      for (var channel = 0; channel < 4; channel++) {
        if (image.bytes[offset + channel] != color[channel]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return true;
      }
    }
  }
  return false;
}

List<int> _rgba(Color color) {
  final value = color.toARGB32();
  return [
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
    (value >> 24) & 0xFF,
  ];
}

List<int> _premultipliedRgba(Color color) {
  final rgba = _rgba(color);
  final alpha = rgba[3] / 255;
  return [
    (rgba[0] * alpha).round(),
    (rgba[1] * alpha).round(),
    (rgba[2] * alpha).round(),
    rgba[3],
  ];
}
