import 'dart:convert';

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path2/graph.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/waypoint.dart';
import 'package:pathplanner/services/project_condition_registry.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

const _nodeA = '11111111-1111-4111-8111-111111111111';
const _nodeB = '22222222-2222-4222-8222-222222222222';
const _nodeC = '33333333-3333-4333-8333-333333333333';
const _nodeD = '44444444-4444-4444-8444-444444444444';
const _branchA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _branchB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _branchC = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _branchD = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

void main() {
  late MemoryFileSystem fs;

  setUp(() {
    fs = MemoryFileSystem();
    ProjectConditionRegistry.clear();
  });

  path2.PathNode node(String id, num x, {num editorY = 0, bool pose = false}) =>
      path2.PathNode(
        id: id,
        waypoint: pose
            ? PoseWaypoint(
                position: Translation2d(x, 1),
                rotation: Rotation2d.fromDegrees(20),
              )
            : TranslationWaypoint(position: Translation2d(x, 1)),
        editorPosition: Offset(50, editorY.toDouble()),
        endTolerance: EndTolerance(distanceMeters: 0.15, angleDegrees: 2.5),
      );

  path2.Path path({
    List<path2.PathNode>? nodes,
    List<path2.PathBranch>? branches,
    String name = 'Test',
    String? folder,
    String sourceVersion = path2.fileVersion,
  }) => path2.Path(
    name: name,
    nodes: nodes ?? [node(_nodeA, 1), node(_nodeB, 2)],
    branches:
        branches ??
        [path2.PathBranch(id: _branchA, sourceId: _nodeA, targetId: _nodeB)],
    pathDir: '/paths',
    fs: fs,
    folder: folder,
    sourceVersion: sourceVersion,
  );

  Map<String, dynamic> validJson() => path().toJson();

  group('path graph model', () {
    test('default path has two vertical pose nodes and a distance branch', () {
      final defaultPath = path2.Path.defaultPath(pathDir: '/paths', fs: fs);

      expect(defaultPath.nodes, hasLength(2));
      expect(
        defaultPath.nodes.every((node) => node.waypoint is PoseWaypoint),
        isTrue,
      );
      expect(
        defaultPath.nodes[0].editorPosition.dx,
        defaultPath.nodes[1].editorPosition.dx,
      );
      expect(
        defaultPath.nodes[1].editorPosition.dy -
            defaultPath.nodes[0].editorPosition.dy,
        greaterThanOrEqualTo(430),
      );
      expect(defaultPath.branches, hasLength(1));
      expect(
        defaultPath.branches.single.transition,
        DistanceTransition(distanceMeters: 0.25),
      );
      expect(defaultPath.diagnostics.isComplete, isTrue);
    });

    test('generated node and branch IDs are stable through round trip', () {
      final defaultPath = path2.Path.defaultPath(pathDir: '/paths', fs: fs);
      final nodeIds = defaultPath.nodes.map((node) => node.id).toList();
      final branchIds = defaultPath.branches
          .map((branch) => branch.id)
          .toList();

      final restored = path2.Path.fromJson(
        defaultPath.toJson(),
        defaultPath.name,
        '/paths',
        fs,
      );

      expect(restored.nodes.map((node) => node.id), nodeIds);
      expect(restored.branches.map((branch) => branch.id), branchIds);
      expect(restored, defaultPath);
    });

    test(
      'round trips layout, waypoint subtypes, tolerances, and transitions',
      () {
        final original = path(
          nodes: [
            node(_nodeA, 1, pose: true),
            node(_nodeB, 2, editorY: 300),
            node(_nodeC, 3, editorY: 600),
          ],
          branches: [
            path2.PathBranch(
              id: _branchA,
              sourceId: _nodeA,
              targetId: _nodeB,
              transition: DistanceTransition(distanceMeters: 0.8),
            ),
            path2.PathBranch(
              id: _branchB,
              sourceId: _nodeB,
              targetId: _nodeC,
              transition: ConditionTransition(conditionName: 'clear'),
            ),
          ],
          folder: 'Qualification',
          sourceVersion: '2028.2.0-beta.1',
        );

        final json = original.toJson();
        final restored = path2.Path.fromJson(json, original.name, '/paths', fs);

        expect(
          json.keys,
          unorderedEquals(['version', 'nodes', 'branches', 'folder']),
        );
        expect(json, isNot(contains('waypoints')));
        expect(json, isNot(contains('eventMarkers')));
        expect(json, isNot(contains('endToleranceMeters')));
        expect(restored, original);
        expect(restored.version, '2028.2.0-beta.1');
        expect(ProjectConditionRegistry.conditions, contains('clear'));
      },
    );

    test('supports splits, merges, multiple leaves, and parallel branches', () {
      final graph = path(
        nodes: [
          node(_nodeA, 1),
          node(_nodeB, 2),
          node(_nodeC, 3),
          node(_nodeD, 4),
        ],
        branches: [
          path2.PathBranch(id: _branchA, sourceId: _nodeA, targetId: _nodeB),
          path2.PathBranch(id: _branchB, sourceId: _nodeA, targetId: _nodeB),
          path2.PathBranch(id: _branchC, sourceId: _nodeA, targetId: _nodeC),
          path2.PathBranch(id: _branchD, sourceId: _nodeB, targetId: _nodeD),
          path2.PathBranch(
            id: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
            sourceId: _nodeC,
            targetId: _nodeD,
          ),
        ],
      );

      expect(graph.rootNodes.map((node) => node.id), [_nodeA]);
      expect(graph.leafNodes.map((node) => node.id), [_nodeD]);
      expect(graph.reverseReachableNodeIds(_nodeD), {
        _nodeA,
        _nodeB,
        _nodeC,
        _nodeD,
      });
      expect(graph.reachableNodeIds, {_nodeA, _nodeB, _nodeC, _nodeD});
      expect(graph.diagnostics.isComplete, isTrue);
    });

    test('disconnected and multiple-root drafts are saveable warnings', () {
      final draft = path(
        nodes: [node(_nodeA, 1), node(_nodeB, 2)],
        branches: [],
      );

      expect(draft.diagnostics.hardErrors, isEmpty);
      expect(draft.diagnostics.draftWarnings, isNotEmpty);
      expect(() => draft.toJson(), returnsNormally);

      final restored = path2.Path.fromJson(
        draft.toJson(),
        draft.name,
        '/paths',
        fs,
      );
      expect(restored.nodes, hasLength(2));
      expect(restored.diagnostics.draftWarnings, isNotEmpty);
    });

    test('unset conditions are configuration warnings and remain nullable', () {
      final draft = path(
        branches: [
          path2.PathBranch(
            id: _branchA,
            sourceId: _nodeA,
            targetId: _nodeB,
            transition: ConditionTransition(),
          ),
        ],
      );

      expect(draft.diagnostics.hardErrors, isEmpty);
      expect(draft.diagnostics.configurationWarnings, hasLength(1));
      final restored = path2.Path.fromJson(
        draft.toJson(),
        draft.name,
        '/paths',
        fs,
      );
      expect(
        (restored.branches.single.transition as ConditionTransition)
            .conditionName,
        isNull,
      );
    });

    test(
      'branch addition rejects self-links and cycles but permits parallel',
      () {
        final graph = path();

        expect(
          graph.addBranch(
            path2.PathBranch(id: _branchB, sourceId: _nodeA, targetId: _nodeB),
          ),
          isTrue,
        );
        expect(
          graph.addBranch(
            path2.PathBranch(id: _branchC, sourceId: _nodeA, targetId: _nodeA),
          ),
          isFalse,
        );
        expect(
          graph.addBranch(
            path2.PathBranch(id: _branchD, sourceId: _nodeB, targetId: _nodeA),
          ),
          isFalse,
        );
      },
    );

    test(
      'node removal removes incident branches and never removes last node',
      () {
        final graph = path();

        expect(graph.removeNode(_nodeA), isTrue);
        expect(graph.nodes.map((node) => node.id), [_nodeB]);
        expect(graph.branches, isEmpty);
        expect(graph.removeNode(_nodeB), isFalse);
      },
    );

    test('snapshots and duplicates are deep copies with stable IDs', () {
      final original = path();
      final snapshot = original.snapshotGraph();
      final duplicate = original.duplicate('Copy');

      original.nodes.first.waypoint.move(9, 10);
      original.nodes.first.endTolerance.distanceMeters = 0.9;
      original.nodes.first.editorPosition = const Offset(900, 900);
      (original.branches.first.transition as DistanceTransition)
              .distanceMeters =
          1.2;
      original.restoreGraph(snapshot);

      expect(original.nodes.first.waypoint.position, const Translation2d(1, 1));
      expect(original.nodes.first.endTolerance.distanceMeters, 0.15);
      expect(original.nodes.first.editorPosition, const Offset(50, 0));
      expect(
        (original.branches.first.transition as DistanceTransition)
            .distanceMeters,
        0.25,
      );

      duplicate.nodes.first.waypoint.move(7, 8);
      expect(duplicate.nodes.first.id, original.nodes.first.id);
      expect(original.nodes.first.waypoint.position, const Translation2d(1, 1));
    });

    test('condition rename and deletion update matching transitions', () {
      final graph = path(
        branches: [
          path2.PathBranch(
            id: _branchA,
            sourceId: _nodeA,
            targetId: _nodeB,
            transition: ConditionTransition(conditionName: 'old'),
          ),
        ],
      );

      expect(graph.updateConditionName('old', 'new'), isTrue);
      expect(graph.getAllConditionNames(), ['new']);
      expect(ProjectConditionRegistry.conditions, contains('new'));
      expect(graph.updateConditionName('new', null), isTrue);
      expect(graph.getAllConditionNames(), isEmpty);
      expect(graph.diagnostics.configurationWarnings, isNotEmpty);
    });
  });

  group('path schema validation', () {
    test(
      'rejects empty, duplicate, dangling, self-linked, and cyclic graphs',
      () {
        final base = validJson();

        expect(
          () =>
              path2.Path.fromJson({...base, 'nodes': []}, 'Bad', '/paths', fs),
          throwsFormatException,
        );

        final duplicateNodes = List<dynamic>.from(
          base['nodes'] as List,
        )..add(Map<String, dynamic>.from((base['nodes'] as List).first as Map));
        expect(
          () => path2.Path.fromJson(
            {...base, 'nodes': duplicateNodes},
            'Bad',
            '/paths',
            fs,
          ),
          throwsFormatException,
        );

        final danglingBranch = Map<String, dynamic>.from(
          (base['branches'] as List).first as Map,
        )..['targetId'] = _nodeC;
        expect(
          () => path2.Path.fromJson(
            {
              ...base,
              'branches': [danglingBranch],
            },
            'Bad',
            '/paths',
            fs,
          ),
          throwsFormatException,
        );

        final selfBranch = Map<String, dynamic>.from(
          (base['branches'] as List).first as Map,
        )..['targetId'] = _nodeA;
        expect(
          () => path2.Path.fromJson(
            {
              ...base,
              'branches': [selfBranch],
            },
            'Bad',
            '/paths',
            fs,
          ),
          throwsFormatException,
        );

        final reverseBranch = path2.PathBranch(
          id: _branchB,
          sourceId: _nodeB,
          targetId: _nodeA,
        ).toJson();
        expect(
          () => path2.Path.fromJson(
            {
              ...base,
              'branches': [...base['branches'] as List, reverseBranch],
            },
            'Bad',
            '/paths',
            fs,
          ),
          throwsFormatException,
        );
      },
    );

    test('rejects graph-wide duplicate IDs', () {
      final base = validJson();
      final duplicateIdBranch = Map<String, dynamic>.from(
        (base['branches'] as List).first as Map,
      )..['id'] = _nodeA;

      expect(
        () => path2.Path.fromJson(
          {
            ...base,
            'branches': [duplicateIdBranch],
          },
          'Bad',
          '/paths',
          fs,
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed and unknown numeric/type payloads', () {
      final base = validJson();

      Map<String, dynamic> changedNode(
        void Function(Map<String, dynamic>) change,
      ) {
        final copied = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
        change((copied['nodes'] as List).first as Map<String, dynamic>);
        return copied;
      }

      expect(
        () => path2.Path.fromJson(
          changedNode((node) => node['editorPosition'] = {'x': 'bad', 'y': 0}),
          'Bad',
          '/paths',
          fs,
        ),
        throwsFormatException,
      );
      expect(
        () => path2.Path.fromJson(
          changedNode(
            (node) => node['endTolerance'] = {
              'distanceMeters': -1,
              'angleDegrees': 2,
            },
          ),
          'Bad',
          '/paths',
          fs,
        ),
        throwsFormatException,
      );
      expect(
        () => path2.Path.fromJson(
          changedNode(
            (node) =>
                (node['waypoint'] as Map<String, dynamic>)['maxVelocity'] = -1,
          ),
          'Bad',
          '/paths',
          fs,
        ),
        throwsFormatException,
      );

      final unknown = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
      ((unknown['branches'] as List).first
          as Map<String, dynamic>)['transition'] = {
        'type': 'mystery',
      };
      expect(
        () => path2.Path.fromJson(unknown, 'Bad', '/paths', fs),
        throwsFormatException,
      );
    });

    test('rejects 2027.0 without migration and accepts future versions', () {
      final base = validJson();
      expect(
        () => path2.Path.fromJson(
          {...base, 'version': '2027.0'},
          'Legacy',
          '/paths',
          fs,
        ),
        throwsFormatException,
      );
      expect(
        path2.Path.fromJson(
          {...base, 'version': '2029.4.0'},
          'Future',
          '/paths',
          fs,
        ).version,
        '2029.4.0',
      );
    });
  });

  group('path files', () {
    test('save, rename, duplicate, and delete preserve folder behavior', () {
      final graph = path(folder: 'Folder');

      graph.saveFile();
      expect(fs.file('/paths/Test.path').existsSync(), isTrue);
      expect(
        (jsonDecode(fs.file('/paths/Test.path').readAsStringSync())
            as Map<String, dynamic>)['folder'],
        'Folder',
      );

      graph.renamePath('Renamed');
      expect(fs.file('/paths/Test.path').existsSync(), isFalse);
      expect(fs.file('/paths/Renamed.path').existsSync(), isTrue);
      expect(graph.duplicate('Copy').folder, 'Folder');

      graph.deletePath();
      expect(fs.file('/paths/Renamed.path').existsSync(), isFalse);
    });

    test('loading rejects legacy files without rewriting them', () async {
      const legacy = '{"version":"2027.0","waypoints":[],"folder":"untouched"}';
      fs.file('/paths/Legacy.path')
        ..createSync(recursive: true)
        ..writeAsStringSync(legacy);

      final loaded = await path2.Path.loadAllPathsInDir('/paths', fs);

      expect(loaded, isEmpty);
      expect(fs.file('/paths/Legacy.path').readAsStringSync(), legacy);
    });

    test(
      'loading retains accepted future version and does not rewrite',
      () async {
        final future = path(sourceVersion: '2030.1.0');
        final source = const JsonEncoder.withIndent('  ')
            .convert(future.toJson());
        fs.file('/paths/Future.path')
          ..createSync(recursive: true)
          ..writeAsStringSync(source);

        final loaded = await path2.Path.loadAllPathsInDir('/paths', fs);

        expect(loaded.single.version, '2030.1.0');
        expect(fs.file('/paths/Future.path').readAsStringSync(), source);
      },
    );
  });
}
