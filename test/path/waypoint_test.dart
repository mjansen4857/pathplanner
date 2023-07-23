import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/waypoint.dart';

const num epsilon = 0.01;

void main() {
  group('Basic functions', () {
    test('Constructor functions', () {
      Waypoint w = Waypoint(
        anchor: const Point(2.0, 2.0),
        prevControl: const Point(1.0, 1.0),
        nextControl: const Point(3.0, 3.0),
      );

      expect(w.anchor, const Point(2.0, 2.0));
      expect(w.prevControl, const Point(1.0, 1.0));
      expect(w.nextControl, const Point(3.0, 3.0));
    });

    test('toJson/fromJson interoperability', () {
      Waypoint w = Waypoint(
        anchor: const Point(2.0, 2.0),
        prevControl: const Point(1.0, 1.0),
        nextControl: const Point(3.0, 3.0),
      );

      Map<String, dynamic> json = w.toJson();
      Waypoint fromJson = Waypoint.fromJson(json);

      expect(fromJson, w);
    });

    test('Proper cloning', () {
      Waypoint w = Waypoint(
        anchor: const Point(2.0, 2.0),
        prevControl: const Point(1.0, 1.0),
        nextControl: const Point(3.0, 3.0),
      );
      Waypoint cloned = w.clone();

      expect(cloned, w);

      cloned.anchor = Point(cloned.anchor.x + 1.0, cloned.anchor.y);

      expect(w, isNot(cloned));
    });

    test('equals/hashCode', () {
      Waypoint w1 = Waypoint(
        anchor: const Point(2.0, 2.0),
        prevControl: const Point(1.0, 1.0),
        nextControl: const Point(3.0, 3.0),
      );
      Waypoint w2 = Waypoint(
        anchor: const Point(2.0, 2.0),
        prevControl: const Point(1.0, 1.0),
        nextControl: const Point(3.0, 3.0),
      );
      Waypoint w3 = Waypoint(
        anchor: const Point(2.0, 2.0),
        prevControl: const Point(1.0, 1.0),
        nextControl: const Point(4.0, 4.0),
      );

      expect(w2, w1);
      expect(w3, isNot(w1));

      expect(w2.hashCode, w1.hashCode);
      expect(w3.hashCode, isNot(w1.hashCode));
    });
  });

  group('Getters', () {
    test('Heading', () {
      Waypoint w = Waypoint(
        anchor: const Point(2.0, 2.0),
        prevControl: const Point(1.0, 2.0),
        nextControl: const Point(3.0, 2.0),
      );

      expect(w.getHeadingRadians(), closeTo(0.0, epsilon));
      expect(w.getHeadingDegrees(), closeTo(0.0, epsilon));

      w = Waypoint(
        anchor: const Point(2.0, 2.0),
        prevControl: const Point(1.0, 1.0),
      );

      expect(w.getHeadingRadians(), closeTo(pi / 4.0, epsilon));
      expect(w.getHeadingDegrees(), closeTo(45, epsilon));

      w = Waypoint(
        anchor: const Point(2.0, 2.0),
        nextControl: const Point(3.0, 3.0),
      );

      expect(w.getHeadingRadians(), closeTo(pi / 4.0, epsilon));
      expect(w.getHeadingDegrees(), closeTo(45, epsilon));

      w = Waypoint(
        anchor: const Point(2.0, 2.0),
        prevControl: const Point(1.0, 3.0),
      );

      expect(w.getHeadingRadians(), closeTo(-pi / 4.0, epsilon));
      expect(w.getHeadingDegrees(), closeTo(-45, epsilon));
    });

    test('Control length', () {
      Waypoint w = Waypoint(
        anchor: const Point(2.0, 2.0),
        prevControl: const Point(1.0, 1.0),
        nextControl: const Point(4.0, 4.0),
      );

      expect(w.getPrevControlLength(), closeTo(1.414, epsilon));
      expect(w.getNextControlLength(), closeTo(2.828, epsilon));
    });

    test('Is start/end point', () {
      Waypoint start = Waypoint(
        anchor: const Point(2.0, 2.0),
        nextControl: const Point(3.0, 3.0),
      );

      expect(start.isStartPoint(), true);
      expect(start.isEndPoint(), false);

      Waypoint mid = Waypoint(
        anchor: const Point(2.0, 2.0),
        prevControl: const Point(1.0, 2.0),
        nextControl: const Point(3.0, 2.0),
      );

      expect(mid.isStartPoint(), false);
      expect(mid.isEndPoint(), false);

      Waypoint end = Waypoint(
        anchor: const Point(2.0, 2.0),
        prevControl: const Point(1.0, 1.0),
      );

      expect(end.isStartPoint(), false);
      expect(end.isEndPoint(), true);
    });
  });

  test('move', () {
    Waypoint w = Waypoint(
      anchor: const Point(2.0, 2.0),
      prevControl: const Point(1.0, 1.0),
      nextControl: const Point(3.0, 3.0),
    );

    w.move(5.5, 4.5);

    expect(w.anchor, const Point(5.5, 4.5));
    expect(w.prevControl, const Point(4.5, 3.5));
    expect(w.nextControl, const Point(6.5, 5.5));
  });

  test('set heading', () {
    Waypoint w = Waypoint(
      anchor: const Point(2.0, 2.0),
      prevControl: const Point(1.5, 1.2),
      nextControl: const Point(4.0, 3.7),
    );

    num prevControlLengh = w.getPrevControlLength();
    num nextControlLength = w.getNextControlLength();

    w.setHeading(107.5);

    expect(w.getHeadingDegrees(), closeTo(107.5, epsilon));
    expect(w.getPrevControlLength(), closeTo(prevControlLengh, epsilon));
    expect(w.getNextControlLength(), closeTo(nextControlLength, epsilon));

    w = Waypoint(
      anchor: const Point(2.0, 2.0),
      nextControl: const Point(4.0, 4.0),
    );

    prevControlLengh = w.getPrevControlLength();
    nextControlLength = w.getNextControlLength();

    w.setHeading(-32.0);

    expect(w.getHeadingDegrees(), closeTo(-32.0, epsilon));
    expect(w.getPrevControlLength(), closeTo(prevControlLengh, epsilon));
    expect(w.getNextControlLength(), closeTo(nextControlLength, epsilon));

    w = Waypoint(
      anchor: const Point(2.0, 2.0),
      prevControl: const Point(0.0, 1.0),
    );

    prevControlLengh = w.getPrevControlLength();
    nextControlLength = w.getNextControlLength();

    w.setHeading(0.0);

    expect(w.getHeadingDegrees(), closeTo(0.0, epsilon));
    expect(w.getPrevControlLength(), closeTo(prevControlLengh, epsilon));
    expect(w.getNextControlLength(), closeTo(nextControlLength, epsilon));
  });

  test('add next control', () {
    Waypoint w = Waypoint(
      anchor: const Point(2.0, 2.0),
      prevControl: const Point(1.0, 1.0),
    );

    expect(w.nextControl, isNull);

    w.addNextControl();

    expect(w.nextControl, const Point(3.0, 3.0));
  });

  test('set control lengths', () {
    Waypoint w = Waypoint(
      anchor: const Point(2.0, 2.0),
      prevControl: const Point(1.0, 1.0),
      nextControl: const Point(3.0, 3.0),
    );

    w.setNextControlLength(2.65);
    expect(w.getNextControlLength(), closeTo(2.65, epsilon));

    w.setPrevControlLength(0.54);
    expect(w.getPrevControlLength(), closeTo(0.54, epsilon));
  });

  test('Hit testing', () {
    Waypoint w = Waypoint(
      anchor: const Point(2.0, 2.0),
      prevControl: const Point(1.0, 1.0),
      nextControl: const Point(3.0, 3.0),
    );

    expect(w.isPointInAnchor(2.5, 2.5, 1.0), true);
    expect(w.isPointInAnchor(2.5, 2.5, 0.2), false);

    expect(w.isPointInPrevControl(1.5, 1.5, 1.0), true);
    expect(w.isPointInPrevControl(1.5, 1.5, 0.2), false);

    expect(w.isPointInNextControl(3.5, 3.5, 1.0), true);
    expect(w.isPointInNextControl(3.5, 3.5, 0.2), false);

    w.prevControl = null;
    expect(w.isPointInPrevControl(1.0, 1.0, 1.0), false);

    w.nextControl = null;
    expect(w.isPointInNextControl(3.0, 3.0, 1.0), false);
  });

  group('dragging', () {
    test('drag anchor', () {
      Waypoint w = Waypoint(
        anchor: const Point(2.0, 2.0),
        prevControl: const Point(1.0, 1.0),
        nextControl: const Point(3.0, 3.0),
      );

      expect(w.startDragging(2.5, 2.5, 0.1, 0.1), false);
      expect(w.startDragging(2.0, 2.0, 0.1, 0.1), true);

      w.isLocked = true;
      w.dragUpdate(2.1, 2.1);
      expect(w.anchor, const Point(2.0, 2.0));

      w.isLocked = false;
      w.dragUpdate(2.1, 2.1);
      expect(w.anchor, const Point(2.1, 2.1));

      w.stopDragging();
      w.dragUpdate(2.2, 2.2);
      expect(w.anchor, const Point(2.1, 2.1));
    });

    test('drag prev control', () {
      Waypoint w = Waypoint(
        anchor: const Point(2.0, 2.0),
        prevControl: const Point(1.0, 1.0),
        nextControl: const Point(3.0, 3.0),
      );

      expect(w.startDragging(1.5, 1.5, 0.1, 0.1), false);
      expect(w.startDragging(1.0, 1.0, 0.1, 0.1), true);

      w.dragUpdate(1.0, 1.1);
      expect(w.prevControl, const Point(1.0, 1.1));
      expect(w.nextControl!.x, closeTo(3.05, epsilon));
      expect(w.nextControl!.y, closeTo(2.95, epsilon));

      num heading = w.getHeadingRadians();

      w.isLocked = true;
      w.dragUpdate(1.2, 2.0);
      expect(w.getHeadingRadians(), closeTo(heading, epsilon));
      expect(w.prevControl!.x, closeTo(1.55, epsilon));
      expect(w.prevControl!.y, closeTo(1.60, epsilon));
      expect(w.nextControl!.x, closeTo(3.05, epsilon));
      expect(w.nextControl!.y, closeTo(2.95, epsilon));

      w.isLocked = false;
      w.stopDragging();
      w.dragUpdate(2.2, 2.2);
      expect(w.prevControl!.x, closeTo(1.55, epsilon));
      expect(w.prevControl!.y, closeTo(1.60, epsilon));
    });

    test('drag next control', () {
      Waypoint w = Waypoint(
        anchor: const Point(2.0, 2.0),
        prevControl: const Point(1.0, 1.0),
        nextControl: const Point(3.0, 3.0),
      );

      expect(w.startDragging(3.5, 3.5, 0.1, 0.1), false);
      expect(w.startDragging(3.0, 3.0, 0.1, 0.1), true);

      w.dragUpdate(3.0, 3.1);
      expect(w.nextControl, const Point(3.0, 3.1));
      expect(w.prevControl!.x, closeTo(1.05, epsilon));
      expect(w.prevControl!.y, closeTo(0.95, epsilon));

      num heading = w.getHeadingRadians();

      w.isLocked = true;
      w.dragUpdate(3.2, 4.0);
      expect(w.getHeadingRadians(), closeTo(heading, epsilon));
      expect(w.nextControl!.x, closeTo(3.54, epsilon));
      expect(w.nextControl!.y, closeTo(3.69, epsilon));
      expect(w.prevControl!.x, closeTo(1.05, epsilon));
      expect(w.prevControl!.y, closeTo(0.95, epsilon));

      w.isLocked = false;
      w.stopDragging();
      w.dragUpdate(4.2, 4.2);
      expect(w.nextControl!.x, closeTo(3.54, epsilon));
      expect(w.nextControl!.y, closeTo(3.69, epsilon));
    });
  });
}
