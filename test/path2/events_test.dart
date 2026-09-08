import 'dart:convert';

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/waypoint.dart';
import 'package:pathplanner/services/project_event_registry.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

void main() {
  setUp(ProjectEventRegistry.clear);

  test(
    'events survive every waypoint conversion and clone without aliasing',
    () {
      final original = TranslationWaypoint(
        position: const Translation2d(),
        events: ['Intake', 'Intake'],
      );
      for (final type in WaypointType.values) {
        final waypoint = original.convertedTo(type);
        expect(waypoint.events, original.events);
        expect(Waypoint.fromJson(waypoint.toJson()), waypoint);
        final copy = waypoint.clone();
        copy.events.removeLast();
        expect(copy, isNot(waypoint));
        expect(waypoint.events, hasLength(2));
      }
      expect(original.withRotation(const Rotation2d()).events, original.events);
      expect(original.withRotation(null).events, original.events);
      expect(
        Waypoint.fromJson(original.toJson()..remove('events')).events,
        isEmpty,
      );
    },
  );

  test(
    'path event files, snapshots, rename and deletion preserve assignments',
    () {
      final fs = MemoryFileSystem();
      fs.directory('/paths').createSync();
      final path = path2.Path.defaultPath(pathDir: '/paths', fs: fs);
      path.nodes.first.waypoint.events = ['Intake', 'Other', 'Intake'];
      path.branches.first.events = [
        path2.BranchEvent(name: 'Intake', position: 0.2),
        path2.BranchEvent(name: 'Intake', position: 0.8),
      ];
      final snapshot = path.snapshotGraph();
      final copy = path.duplicate('Copy');
      copy.branches.first.events.clear();
      expect(path.branches.first.events, hasLength(2));
      path.saveFile();
      final decoded = jsonDecode(
        fs.file('/paths/New Path.path').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(decoded['version'], path2.fileVersion);
      expect((decoded['branches'] as List).first['events'], [
        {'name': 'Intake', 'position': 0.2},
        {'name': 'Intake', 'position': 0.8},
      ]);
      ProjectEventRegistry.clear();
      final loaded = path2.Path.fromJson(decoded, 'New Path', '/paths', fs);
      expect(loaded.branches, path.branches);
      expect(ProjectEventRegistry.events, containsAll(['Intake', 'Other']));
      expect(loaded.replaceEventName('Intake', 'Acquire'), isTrue);
      expect(loaded.nodes.first.waypoint.events, [
        'Acquire',
        'Other',
        'Acquire',
      ]);
      expect(loaded.branches.first.events.map((e) => e.position), [0.2, 0.8]);
      expect(loaded.replaceEventName('Acquire', null), isTrue);
      expect(loaded.branches.first.events, isEmpty);
      expect(loaded.nodes.first.waypoint.events, ['Other']);
      loaded.restoreGraph(snapshot);
      expect(loaded.branches.first.events, path.branches.first.events);
      expect(
        loaded.nodes.first.waypoint.events,
        path.nodes.first.waypoint.events,
      );
      final oldBranch = path.branches.first.toJson()..remove('events');
      expect(path2.PathBranch.fromJson(oldBranch).events, isEmpty);
    },
  );

  test('malformed names and positions are rejected', () {
    for (final position in [-0.1, 1.1, double.nan, double.infinity]) {
      expect(
        () => path2.BranchEvent(name: 'Event', position: position),
        throwsArgumentError,
      );
      expect(
        () =>
            path2.BranchEvent.fromJson({'name': 'Event', 'position': position}),
        throwsFormatException,
      );
    }
    expect(() => path2.BranchEvent(name: '  '), throwsArgumentError);
    for (final value in [
      'Event',
      [1],
      [' '],
    ]) {
      final json = TranslationWaypoint(position: const Translation2d()).toJson()
        ..['events'] = value;
      expect(() => Waypoint.fromJson(json), throwsFormatException);
    }
  });
}
