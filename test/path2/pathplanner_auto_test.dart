import 'dart:convert';

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path2/graph.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/pathplanner_auto.dart' as path2_auto;
import 'package:pathplanner/path2/waypoint.dart';
import 'package:pathplanner/services/project_condition_registry.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

const _nodeA = '11111111-1111-4111-8111-111111111111';
const _nodeB = '22222222-2222-4222-8222-222222222222';
const _nodeC = '33333333-3333-4333-8333-333333333333';
const _branchA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _branchB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _branchC = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

void main() {
  late MemoryFileSystem fs;

  setUp(() {
    fs = MemoryFileSystem();
    ProjectConditionRegistry.clear();
  });

  path2_auto.PathAutoNode node(String id, String? pathName, {double y = 0}) =>
      path2_auto.PathAutoNode(
        id: id,
        pathName: pathName,
        editorPosition: Offset(80, y),
      );

  path2_auto.Path2Auto auto({
    List<path2_auto.AutoNode>? nodes,
    List<path2_auto.AutoBranch>? branches,
    String name = 'Test Auto',
    String? folder,
    String sourceVersion = path2_auto.fileVersion,
    Pose2d startingPose = const Pose2d(Translation2d(), Rotation2d()),
    bool initialized = false,
  }) => path2_auto.Path2Auto(
    name: name,
    nodes: nodes ?? [node(_nodeA, 'First'), node(_nodeB, 'Second', y: 300)],
    branches:
        branches ??
        [
          path2_auto.AutoBranch(
            id: _branchA,
            sourceId: _nodeA,
            targetId: _nodeB,
            transition: const FinishedTransition(),
          ),
        ],
    autoDir: '/autos',
    fs: fs,
    folder: folder,
    sourceVersion: sourceVersion,
    startingPose: startingPose,
    startingPoseInitialized: initialized,
  );

  path2.Path posePath(
    String name,
    Translation2d position, {
    Rotation2d rotation = const Rotation2d(),
    bool multipleRoots = false,
  }) {
    final first = path2.PathNode(
      id: '91111111-1111-4111-8111-111111111111',
      waypoint: PoseWaypoint(position: position, rotation: rotation),
      editorPosition: const Offset(0, 0),
    );
    final second = path2.PathNode(
      id: '92222222-2222-4222-8222-222222222222',
      waypoint: TranslationWaypoint(position: const Translation2d(4, 5)),
      editorPosition: const Offset(0, 200),
    );
    return path2.Path(
      name: name,
      nodes: [first, second],
      branches: multipleRoots
          ? []
          : [
              path2.PathBranch(
                id: '9aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                sourceId: first.id,
                targetId: second.id,
              ),
            ],
      pathDir: '/paths',
      fs: fs,
    );
  }

  Map<String, dynamic> validJson() => auto().toJson();

  group('auto graph model', () {
    test('new autos are empty and valid', () {
      final empty = path2_auto.Path2Auto.defaultAuto(autoDir: '/autos', fs: fs);

      expect(empty.nodes, isEmpty);
      expect(empty.branches, isEmpty);
      expect(empty.diagnostics.hardErrors, isEmpty);
      expect(empty.diagnostics.draftWarnings, isEmpty);
      expect(empty.toJson(), isNot(contains('command')));
    });

    test(
      'round trips nodes, branches, layout, pose, folder, and future version',
      () {
        final original = auto(
          nodes: [
            node(_nodeA, 'First'),
            node(_nodeB, 'Second', y: 250),
            node(_nodeC, null, y: 500),
          ],
          branches: [
            path2_auto.AutoBranch(
              id: _branchA,
              sourceId: _nodeA,
              targetId: _nodeB,
              transition: const FinishedTransition(),
            ),
            path2_auto.AutoBranch(
              id: _branchB,
              sourceId: _nodeB,
              targetId: _nodeC,
              transition: ConditionTransition(conditionName: 'ready'),
            ),
          ],
          sourceVersion: '2029.1.0-beta.2',
          folder: 'Playoffs',
          startingPose: Pose2d(
            const Translation2d(2.5, 6.5),
            Rotation2d.fromDegrees(45),
          ),
          initialized: true,
        );

        final json = original.toJson();
        final restored = path2_auto.Path2Auto.fromJson(
          json,
          original.name,
          '/autos',
          fs,
        );

        expect(
          json.keys,
          unorderedEquals([
            'version',
            'nodes',
            'branches',
            'startingPose',
            'startingPoseInitialized',
            'folder',
          ]),
        );
        expect(restored, original);
        expect(restored.version, '2029.1.0-beta.2');
        expect(ProjectConditionRegistry.conditions, contains('ready'));
      },
    );

    test(
      'supports parallel condition branches and finished plus condition',
      () {
        final graph = auto(
          branches: [
            path2_auto.AutoBranch(
              id: _branchA,
              sourceId: _nodeA,
              targetId: _nodeB,
              transition: const FinishedTransition(),
            ),
            path2_auto.AutoBranch(
              id: _branchB,
              sourceId: _nodeA,
              targetId: _nodeB,
              transition: ConditionTransition(conditionName: 'fast'),
            ),
            path2_auto.AutoBranch(
              id: _branchC,
              sourceId: _nodeA,
              targetId: _nodeB,
              transition: ConditionTransition(conditionName: 'safe'),
            ),
          ],
        );

        expect(graph.diagnostics.hardErrors, isEmpty);
        expect(graph.rootNodes.map((node) => node.id), [_nodeA]);
        expect(graph.leafNodes.map((node) => node.id), [_nodeB]);
      },
    );

    test('multiple roots and disconnected nodes are saveable drafts', () {
      final draft = auto(branches: []);

      expect(draft.diagnostics.hardErrors, isEmpty);
      expect(draft.diagnostics.draftWarnings, isNotEmpty);
      expect(() => draft.toJson(), returnsNormally);
      expect(
        path2_auto.Path2Auto.fromJson(
          draft.toJson(),
          draft.name,
          '/autos',
          fs,
        ).diagnostics.draftWarnings,
        isNotEmpty,
      );
    });

    test('unset conditions and path names are configuration warnings', () {
      final draft = auto(
        nodes: [node(_nodeA, null), node(_nodeB, 'Missing', y: 300)],
        branches: [
          path2_auto.AutoBranch(
            id: _branchA,
            sourceId: _nodeA,
            targetId: _nodeB,
          ),
        ],
      );

      expect(draft.diagnostics.configurationWarnings, hasLength(2));
      expect(
        draft.getDiagnostics(paths: const []).configurationWarnings,
        hasLength(3),
      );
      expect(() => draft.toJson(), returnsNormally);
    });

    test('branch helpers reject cycles and duplicate finished transitions', () {
      final graph = auto();

      expect(
        graph.addBranch(
          path2_auto.AutoBranch(
            id: _branchB,
            sourceId: _nodeA,
            targetId: _nodeB,
            transition: const FinishedTransition(),
          ),
        ),
        isFalse,
      );
      expect(
        graph.addBranch(
          path2_auto.AutoBranch(
            id: _branchB,
            sourceId: _nodeB,
            targetId: _nodeA,
            transition: ConditionTransition(conditionName: 'back'),
          ),
        ),
        isFalse,
      );
      expect(graph.removeBranch(_branchA), isTrue);
      expect(
        graph.addBranch(
          path2_auto.AutoBranch(
            id: _branchB,
            sourceId: _nodeA,
            targetId: _nodeB,
            transition: const FinishedTransition(),
          ),
        ),
        isTrue,
      );
    });

    test('auto can return to empty and snapshots are deep copies', () {
      final graph = auto();
      final snapshot = graph.snapshotGraph();

      expect(graph.removeNode(_nodeA), isTrue);
      expect(graph.removeNode(_nodeB), isTrue);
      expect(graph.nodes, isEmpty);
      expect(graph.branches, isEmpty);
      graph.setStartingPose(
        Pose2d(const Translation2d(9, 8), Rotation2d.fromDegrees(45)),
      );

      graph.restoreGraph(snapshot);
      expect(graph.startingPose.translation, const Translation2d());
      expect(graph.startingPose.rotation, const Rotation2d());
      expect(graph.startingPoseInitialized, isFalse);
      (graph.nodes.first as path2_auto.PathAutoNode).pathName = 'Changed';
      expect(
        (snapshot.nodes.first as path2_auto.PathAutoNode).pathName,
        'First',
      );
      expect(
        (graph.duplicate('Copy').nodes.first as path2_auto.PathAutoNode)
            .pathName,
        'Changed',
      );
    });

    test('path rename and deletion retain node occurrences', () {
      final graph = auto(
        nodes: [node(_nodeA, 'Shared'), node(_nodeB, 'Shared', y: 300)],
      );
      expect(graph.getAllPathNames(), ['Shared', 'Shared']);

      graph.updatePathName('Shared', 'Renamed');
      expect(graph.getAllPathNames(), ['Renamed', 'Renamed']);
      expect(fs.file('/autos/Test Auto.auto').existsSync(), isTrue);

      expect(graph.handleMissingPaths(['Other']), isTrue);
      expect(graph.nodes.whereType<path2_auto.PathAutoNode>().length, 2);
      expect(graph.hasEmptyPathNodes(), isTrue);
      expect(graph.getAllPathNames(), isEmpty);
    });

    test('condition rename and deletion update all matching branches', () {
      final graph = auto(
        branches: [
          path2_auto.AutoBranch(
            id: _branchA,
            sourceId: _nodeA,
            targetId: _nodeB,
            transition: ConditionTransition(conditionName: 'old'),
          ),
          path2_auto.AutoBranch(
            id: _branchB,
            sourceId: _nodeA,
            targetId: _nodeB,
            transition: ConditionTransition(conditionName: 'old'),
          ),
        ],
      );

      expect(graph.updateConditionName('old', 'new'), isTrue);
      expect(graph.getAllConditionNames(), ['new', 'new']);
      expect(ProjectConditionRegistry.conditions, contains('new'));
      expect(graph.updateConditionName('new', null), isTrue);
      expect(graph.diagnostics.configurationWarnings, hasLength(2));
    });
  });

  group('starting pose', () {
    test('seeds once from the unique auto root and unique path root', () {
      final resolved = posePath(
        'First',
        const Translation2d(3, 4),
        rotation: Rotation2d.fromDegrees(90),
      );
      final graph = auto(nodes: [node(_nodeA, 'First')], branches: []);

      expect(graph.initializeStartingPoseFromPaths([resolved]), isTrue);
      expect(graph.startingPose.translation, const Translation2d(3, 4));
      expect(graph.startingPose.rotation.degrees, closeTo(90, 1e-9));

      (graph.nodes.single as path2_auto.PathAutoNode).pathName = 'Other';
      expect(
        graph.initializeStartingPoseFromPaths([
          posePath('Other', const Translation2d(8, 9)),
        ]),
        isFalse,
      );
      expect(graph.startingPose.translation, const Translation2d(3, 4));
    });

    test('does not seed from multiple auto roots or a draft path root', () {
      final multipleAutoRoots = auto(branches: []);
      expect(
        multipleAutoRoots.initializeStartingPoseFromPaths([
          posePath('First', const Translation2d(3, 4)),
          posePath('Second', const Translation2d(5, 6)),
        ]),
        isFalse,
      );

      final graph = auto(nodes: [node(_nodeA, 'First')], branches: []);
      expect(
        graph.initializeStartingPoseFromPaths([
          posePath('First', const Translation2d(3, 4), multipleRoots: true),
        ]),
        isFalse,
      );
    });

    test('manual pose is authoritative and invalid poses are rejected', () {
      final graph = auto(nodes: [node(_nodeA, 'First')], branches: []);
      graph.setStartingPose(
        Pose2d(const Translation2d(8, 9), Rotation2d.fromDegrees(15)),
      );

      expect(
        graph.initializeStartingPoseFromPaths([
          posePath('First', const Translation2d(3, 4)),
        ]),
        isFalse,
      );
      expect(graph.startingPose.translation, const Translation2d(8, 9));
      expect(
        () => graph.setStartingPose(
          const Pose2d(Translation2d(double.nan, 0), Rotation2d()),
        ),
        throwsArgumentError,
      );
    });
  });

  group('auto schema validation', () {
    test('rejects duplicate, dangling, self-linked, and cyclic graphs', () {
      final base = validJson();
      final nodes = base['nodes'] as List;
      final branches = base['branches'] as List;

      expect(
        () => path2_auto.Path2Auto.fromJson(
          {
            ...base,
            'nodes': [...nodes, Map<String, dynamic>.from(nodes.first as Map)],
          },
          'Bad',
          '/autos',
          fs,
        ),
        throwsFormatException,
      );

      final dangling = Map<String, dynamic>.from(branches.first as Map)
        ..['targetId'] = _nodeC;
      expect(
        () => path2_auto.Path2Auto.fromJson(
          {
            ...base,
            'branches': [dangling],
          },
          'Bad',
          '/autos',
          fs,
        ),
        throwsFormatException,
      );

      final self = Map<String, dynamic>.from(branches.first as Map)
        ..['targetId'] = _nodeA;
      expect(
        () => path2_auto.Path2Auto.fromJson(
          {
            ...base,
            'branches': [self],
          },
          'Bad',
          '/autos',
          fs,
        ),
        throwsFormatException,
      );

      final reverse = path2_auto.AutoBranch(
        id: _branchB,
        sourceId: _nodeB,
        targetId: _nodeA,
        transition: ConditionTransition(conditionName: 'back'),
      ).toJson();
      expect(
        () => path2_auto.Path2Auto.fromJson(
          {
            ...base,
            'branches': [...branches, reverse],
          },
          'Bad',
          '/autos',
          fs,
        ),
        throwsFormatException,
      );
    });

    test('rejects more than one finished transition from a node', () {
      final invalid = auto(
        nodes: [
          node(_nodeA, 'First'),
          node(_nodeB, 'Second'),
          node(_nodeC, 'Third'),
        ],
        branches: [
          path2_auto.AutoBranch(
            id: _branchA,
            sourceId: _nodeA,
            targetId: _nodeB,
            transition: const FinishedTransition(),
          ),
        ],
      ).toJson();
      (invalid['branches'] as List).add(
        path2_auto.AutoBranch(
          id: _branchB,
          sourceId: _nodeA,
          targetId: _nodeC,
          transition: const FinishedTransition(),
        ).toJson(),
      );

      expect(
        () => path2_auto.Path2Auto.fromJson(invalid, 'Bad', '/autos', fs),
        throwsFormatException,
      );
    });

    test(
      'rejects malformed node/transition/pose payloads and unknown types',
      () {
        final base = validJson();
        final malformed = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
        ((malformed['nodes'] as List).first
            as Map<String, dynamic>)['editorPosition'] = {
          'x': double.nan,
          'y': 0,
        };
        expect(
          () => path2_auto.Path2Auto.fromJson(malformed, 'Bad', '/autos', fs),
          throwsFormatException,
        );

        final unknownNode =
            jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
        ((unknownNode['nodes'] as List).first as Map<String, dynamic>)['type'] =
            'wait';
        expect(
          () => path2_auto.Path2Auto.fromJson(unknownNode, 'Bad', '/autos', fs),
          throwsFormatException,
        );

        final unknownTransition =
            jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
        ((unknownTransition['branches'] as List).first
            as Map<String, dynamic>)['transition'] = {
          'type': 'distance',
          'distanceMeters': 1,
        };
        expect(
          () => path2_auto.Path2Auto.fromJson(
            unknownTransition,
            'Bad',
            '/autos',
            fs,
          ),
          throwsFormatException,
        );

        expect(
          () => path2_auto.Path2Auto.fromJson(
            {
              ...base,
              'startingPose': {
                'position': {'x': 0, 'y': 0},
                'rotation': double.infinity,
              },
            },
            'Bad',
            '/autos',
            fs,
          ),
          throwsFormatException,
        );
      },
    );

    test(
      'cleanly rejects 2027.0 command autos and accepts future versions',
      () {
        final base = validJson();
        expect(
          () => path2_auto.Path2Auto.fromJson(
            {
              'version': '2027.0',
              'command': {
                'type': 'sequential',
                'data': {'commands': []},
              },
            },
            'Legacy',
            '/autos',
            fs,
          ),
          throwsFormatException,
        );
        expect(
          path2_auto.Path2Auto.fromJson(
            {...base, 'version': '2030.2.0'},
            'Future',
            '/autos',
            fs,
          ).version,
          '2030.2.0',
        );
      },
    );
  });

  group('auto files', () {
    test('save, rename, duplicate, and delete preserve folder', () {
      final graph = auto(folder: 'Folder');
      graph.saveFile();
      expect(fs.file('/autos/Test Auto.auto').existsSync(), isTrue);

      graph.rename('Renamed');
      expect(fs.file('/autos/Test Auto.auto').existsSync(), isFalse);
      expect(fs.file('/autos/Renamed.auto').existsSync(), isTrue);
      expect(graph.duplicate('Copy').folder, 'Folder');

      graph.delete();
      expect(fs.file('/autos/Renamed.auto').existsSync(), isFalse);
    });

    test('filters Choreo and rejects legacy files without rewriting', () async {
      const choreo =
          '{"version":"old","choreoAuto":true,"command":{"broken":true}}';
      const legacy = '{"version":"2027.0","command":{}}';
      fs.file('/autos/Choreo.auto')
        ..createSync(recursive: true)
        ..writeAsStringSync(choreo);
      fs.file('/autos/Legacy.auto').writeAsStringSync(legacy);

      final loaded = await path2_auto.Path2Auto.loadAllAutosInDir('/autos', fs);

      expect(loaded, isEmpty);
      expect(fs.file('/autos/Choreo.auto').readAsStringSync(), choreo);
      expect(fs.file('/autos/Legacy.auto').readAsStringSync(), legacy);
    });

    test('loads accepted future files without rewriting', () async {
      final future = auto(sourceVersion: '2031.3.0');
      final source = const JsonEncoder.withIndent('  ')
          .convert(future.toJson());
      fs.file('/autos/Future.auto')
        ..createSync(recursive: true)
        ..writeAsStringSync(source);

      final loaded = await path2_auto.Path2Auto.loadAllAutosInDir('/autos', fs);

      expect(loaded.single.version, '2031.3.0');
      expect(fs.file('/autos/Future.auto').readAsStringSync(), source);
    });
  });
}
