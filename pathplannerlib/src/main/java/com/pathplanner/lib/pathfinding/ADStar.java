package com.pathplanner.lib.pathfinding;

import edu.wpi.first.math.Pair;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.wpilibj.DriverStation;
import edu.wpi.first.wpilibj.Filesystem;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.*;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

public class ADStar {
  private static final double SMOOTHING_ANCHOR_PCT = 0.8;
  private static final double SMOOTHING_CONTROL_PCT = 0.33;

  public static double FIELD_LENGTH = 16.54;
  public static double FIELD_WIDTH = 8.02;

  public static double NODE_SIZE = 0.2;

  public static int NODE_X = (int) Math.ceil(FIELD_LENGTH / NODE_SIZE);
  public static int NODE_Y = (int) Math.ceil(FIELD_WIDTH / NODE_SIZE);

  private static final double EPS = 2.5;

  private static final HashMap<GridPosition, Double> g = new HashMap<>();
  private static final HashMap<GridPosition, Double> rhs = new HashMap<>();
  private static final HashMap<GridPosition, Pair<Double, Double>> open = new HashMap<>();
  private static final HashMap<GridPosition, Pair<Double, Double>> incons = new HashMap<>();
  private static final Set<GridPosition> closed = new HashSet<>();
  private static final Set<GridPosition> staticObstacles = new HashSet<>();
  private static final Set<GridPosition> dynamicObstacles = new HashSet<>();
  private static final Set<GridPosition> obstacles = new HashSet<>();

  private static volatile GridPosition sStart;
  private static volatile Translation2d realStartPos;
  private static volatile GridPosition sGoal;
  private static volatile Translation2d realGoalPos;

  private static double eps;

  private static final Thread planningThread = new Thread(ADStar::runThread);
  private static final Object lock = new Object();
  private static volatile boolean doMinor = true;
  private static volatile boolean doMajor = true;
  private static volatile boolean needsReset = true;
  private static volatile boolean needsExtract = false;
  private static volatile boolean running = false;
  private static volatile boolean newPathAvailable = false;

  private static volatile List<Translation2d> currentPath = new ArrayList<>();

  public static void ensureInitialized() {
    if (!running) {
      running = true;
      sStart = new GridPosition(0, 0);
      realStartPos = new Translation2d(0, 0);
      sGoal = new GridPosition(0, 0);
      realGoalPos = new Translation2d(0, 0);

      staticObstacles.clear();
      dynamicObstacles.clear();

      File navGridFile = new File(Filesystem.getDeployDirectory(), "pathplanner/navgrid.json");
      if (navGridFile.exists()) {
        try (BufferedReader br = new BufferedReader(new FileReader(navGridFile))) {
          StringBuilder fileContentBuilder = new StringBuilder();
          String line;
          while ((line = br.readLine()) != null) {
            fileContentBuilder.append(line);
          }

          String fileContent = fileContentBuilder.toString();
          JSONObject json = (JSONObject) new JSONParser().parse(fileContent);

          NODE_SIZE = ((Number) json.get("nodeSizeMeters")).doubleValue();
          JSONArray grid = (JSONArray) json.get("grid");
          NODE_Y = grid.size();
          for (int row = 0; row < grid.size(); row++) {
            JSONArray rowArray = (JSONArray) grid.get(row);
            if (row == 0) {
              NODE_X = rowArray.size();
            }
            for (int col = 0; col < rowArray.size(); col++) {
              boolean isObstacle = (boolean) rowArray.get(col);
              if (isObstacle) {
                staticObstacles.add(new GridPosition(col, row));
              }
            }
          }

          JSONObject fieldSize = (JSONObject) json.get("field_size");
          FIELD_LENGTH = ((Number) fieldSize.get("x")).doubleValue();
          FIELD_WIDTH = ((Number) fieldSize.get("y")).doubleValue();
        } catch (Exception e) {
          e.printStackTrace();
        }
      }

      obstacles.clear();
      obstacles.addAll(staticObstacles);
      obstacles.addAll(dynamicObstacles);

      needsReset = true;
      doMajor = true;
      doMinor = true;

      newPathAvailable = false;

      planningThread.setDaemon(true);
      planningThread.setName("ADStar Planning Thread");
      planningThread.start();
    }
  }

  private static void runThread() {
    while (running) {
      try {
        synchronized (lock) {
          if (needsReset || doMinor || doMajor) {
            doWork();
          } else if (needsExtract) {
            currentPath = extractPath();
            newPathAvailable = true;
            needsExtract = false;
          }
        }

        if (!needsReset && !doMinor && !doMajor) {
          try {
            Thread.sleep(20);
          } catch (InterruptedException e) {
            throw new RuntimeException(e);
          }
        }
      } catch (Exception e) {
        //        e.printStackTrace();
      }
    }
  }

  private static void doWork() {
    if (needsReset) {
      reset();
      needsReset = false;
    }

    if (doMinor) {
      computeOrImprovePath();
      currentPath = extractPath();
      newPathAvailable = true;
      doMinor = false;
    } else if (doMajor) {
      if (eps > 1.0) {
        eps -= 0.5;
        open.putAll(incons);

        open.replaceAll((s, v) -> key(s));
        closed.clear();
        computeOrImprovePath();
        currentPath = extractPath();
        newPathAvailable = true;
      }

      if (eps <= 1.0) {
        doMajor = false;
      }
    }
  }

  public static boolean isNewPathAvailable() {
    return newPathAvailable;
  }

  public static List<Translation2d> getCurrentPath() {
    if (!running) {
      DriverStation.reportWarning("ADStar path was retrieved before it was initialized", false);
    }

    newPathAvailable = false;
    return currentPath;
  }

  public static void setStartPos(Translation2d start) {
    synchronized (lock) {
      GridPosition startPos = findClosestNonObstacle(getGridPos(start));

      if (startPos != null && !startPos.equals(sStart)) {
        sStart = startPos;
        realStartPos = start;

        doMinor = true;
      }
    }
  }

  public static void setGoalPos(Translation2d goal) {
    synchronized (lock) {
      GridPosition gridPos = findClosestNonObstacle(getGridPos(goal));

      if (gridPos != null) {
        sGoal = gridPos;
        realGoalPos = goal;

        doMinor = true;
        doMajor = true;
        needsReset = true;
      }
    }
  }

  private static GridPosition findClosestNonObstacle(GridPosition pos) {
    if (!obstacles.contains(pos)) {
      return pos;
    }

    Set<GridPosition> visited = new HashSet<>();

    Queue<GridPosition> queue = new LinkedList<>(getAllNeighbors(pos));

    while (!queue.isEmpty()) {
      GridPosition check = queue.poll();
      if (!obstacles.contains(check)) {
        return check;
      }
      visited.add(check);

      for (GridPosition neighbor : getAllNeighbors(check)) {
        if (!visited.contains(neighbor)) {
          queue.add(neighbor);
        }
      }
    }
    return null;
  }

  public static void setDynamicObstacles(
      List<Pair<Translation2d, Translation2d>> obs, Translation2d currentRobotPos) {
    Set<GridPosition> newObs = new HashSet<>();

    for (var obstacle : obs) {
      var gridPos1 = getGridPos(obstacle.getFirst());
      var gridPos2 = getGridPos(obstacle.getSecond());

      int minX = Math.min(gridPos1.x, gridPos2.x);
      int maxX = Math.max(gridPos1.x, gridPos2.x);

      int minY = Math.min(gridPos1.y, gridPos2.y);
      int maxY = Math.max(gridPos1.y, gridPos2.y);

      for (int x = minX; x <= maxX; x++) {
        for (int y = minY; y <= maxY; y++) {
          newObs.add(new GridPosition(x, y));
        }
      }
    }

    synchronized (lock) {
      dynamicObstacles.clear();
      dynamicObstacles.addAll(newObs);
      obstacles.clear();
      obstacles.addAll(staticObstacles);
      obstacles.addAll(dynamicObstacles);
      needsReset = true;
      doMinor = true;
      doMajor = true;

      if (dynamicObstacles.contains(getGridPos(currentRobotPos))) {
        // Set the start position to the closest non-obstacle
        setStartPos(currentRobotPos);
      }
    }
  }

  private static List<Translation2d> extractPath() {
    if (sGoal.equals(sStart)) {
      return List.of(realGoalPos);
    }

    List<GridPosition> path = new ArrayList<>();
    path.add(sStart);

    var s = sStart;

    for (int k = 0; k < 200; k++) {
      HashMap<GridPosition, Double> gList = new HashMap<>();

      for (GridPosition x : getOpenNeighbors(s)) {
        gList.put(x, g.get(x));
      }

      Map.Entry<GridPosition, Double> min = Map.entry(sGoal, Double.POSITIVE_INFINITY);
      for (var entry : gList.entrySet()) {
        if (entry.getValue() < min.getValue()) {
          min = entry;
        }
      }
      s = min.getKey();

      path.add(s);
      if (s.equals(sGoal)) {
        break;
      }
    }

    List<GridPosition> simplifiedPath = new ArrayList<>();
    simplifiedPath.add(path.get(0));
    for (int i = 1; i < path.size() - 1; i++) {
      if (!walkable(simplifiedPath.get(simplifiedPath.size() - 1), path.get(i + 1))) {
        simplifiedPath.add(path.get(i));
      }
    }
    simplifiedPath.add(path.get(path.size() - 1));

    List<Translation2d> fieldPosPath = new ArrayList<>();
    for (GridPosition pos : simplifiedPath) {
      fieldPosPath.add(gridPosToTranslation2d(pos));
    }

    // Replace start and end positions with their real positions
    fieldPosPath.set(0, realStartPos);
    fieldPosPath.set(fieldPosPath.size() - 1, realGoalPos);

    List<Translation2d> bezierPoints = new ArrayList<>();
    bezierPoints.add(fieldPosPath.get(0));
    bezierPoints.add(
        fieldPosPath
            .get(1)
            .minus(fieldPosPath.get(0))
            .times(SMOOTHING_CONTROL_PCT)
            .plus(fieldPosPath.get(0)));
    for (int i = 1; i < fieldPosPath.size() - 1; i++) {
      Translation2d last = fieldPosPath.get(i - 1);
      Translation2d current = fieldPosPath.get(i);
      Translation2d next = fieldPosPath.get(i + 1);

      Translation2d anchor1 = current.minus(last).times(SMOOTHING_ANCHOR_PCT).plus(last);
      Translation2d anchor2 = current.minus(next).times(SMOOTHING_ANCHOR_PCT).plus(next);

      double controlDist = anchor1.getDistance(anchor2) * SMOOTHING_CONTROL_PCT;

      Translation2d prevControl1 = last.minus(anchor1).times(SMOOTHING_CONTROL_PCT).plus(anchor1);
      Translation2d nextControl1 =
          new Translation2d(controlDist, anchor1.minus(prevControl1).getAngle()).plus(anchor1);

      Translation2d prevControl2 =
          new Translation2d(controlDist, anchor2.minus(next).getAngle()).plus(anchor2);
      Translation2d nextControl2 = next.minus(anchor2).times(SMOOTHING_CONTROL_PCT).plus(anchor2);

      bezierPoints.add(prevControl1);
      bezierPoints.add(anchor1);
      bezierPoints.add(nextControl1);

      bezierPoints.add(prevControl2);
      bezierPoints.add(anchor2);
      bezierPoints.add(nextControl2);
    }
    bezierPoints.add(
        fieldPosPath
            .get(fieldPosPath.size() - 2)
            .minus(fieldPosPath.get(fieldPosPath.size() - 1))
            .times(SMOOTHING_CONTROL_PCT)
            .plus(fieldPosPath.get(fieldPosPath.size() - 1)));
    bezierPoints.add(fieldPosPath.get(fieldPosPath.size() - 1));

    return bezierPoints;
  }

  private static boolean walkable(GridPosition s1, GridPosition s2) {
    int x0 = s1.x;
    int y0 = s1.y;
    int x1 = s2.x;
    int y1 = s2.y;

    int dx = Math.abs(x1 - x0);
    int dy = Math.abs(y1 - y0);
    int x = x0;
    int y = y0;
    int n = 1 + dx + dy;
    int xInc = (x1 > x0) ? 1 : -1;
    int yInc = (y1 > y0) ? 1 : -1;
    int error = dx - dy;
    dx *= 2;
    dy *= 2;

    for (; n > 0; n--) {
      if (obstacles.contains(new GridPosition(x, y))) {
        return false;
      }

      if (error > 0) {
        x += xInc;
        error -= dy;
      } else if (error < 0) {
        y += yInc;
        error += dx;
      } else {
        x += xInc;
        y += yInc;
        error -= dy;
        error += dx;
        n--;
      }
    }

    return true;
  }

  private static void reset() {
    g.clear();
    rhs.clear();
    open.clear();
    incons.clear();
    closed.clear();

    for (int x = 0; x < NODE_X; x++) {
      for (int y = 0; y < NODE_Y; y++) {
        g.put(new GridPosition(x, y), Double.POSITIVE_INFINITY);
        rhs.put(new GridPosition(x, y), Double.POSITIVE_INFINITY);
      }
    }

    rhs.put(sGoal, 0.0);

    eps = EPS;

    open.put(sGoal, key(sGoal));
  }

  private static void computeOrImprovePath() {
    while (true) {
      var sv = topKey();
      if (sv == null) {
        break;
      }
      var s = sv.getFirst();
      var v = sv.getSecond();

      if (comparePair(v, key(sStart)) >= 0 && rhs.get(sStart).equals(g.get(sStart))) {
        break;
      }

      open.remove(s);

      if (g.get(s) > rhs.get(s)) {
        g.put(s, rhs.get(s));
        closed.add(s);

        for (GridPosition sn : getOpenNeighbors(s)) {
          updateState(sn);
        }
      } else {
        g.put(s, Double.POSITIVE_INFINITY);
        for (GridPosition sn : getOpenNeighbors(s)) {
          updateState(sn);
        }
        updateState(s);
      }
    }
  }

  private static void updateState(GridPosition s) {
    if (!s.equals(sGoal)) {
      rhs.put(s, Double.POSITIVE_INFINITY);

      for (GridPosition x : getOpenNeighbors(s)) {
        rhs.put(s, Math.min(rhs.get(s), g.get(x) + cost(s, x)));
      }
    }

    open.remove(s);

    if (!g.get(s).equals(rhs.get(s))) {
      if (!closed.contains(s)) {
        open.put(s, key(s));
      } else {
        incons.put(s, Pair.of(0.0, 0.0));
      }
    }
  }

  private static double cost(GridPosition sStart, GridPosition sGoal) {
    if (isCollision(sStart, sGoal)) {
      return Double.POSITIVE_INFINITY;
    }

    return heuristic(sStart, sGoal);
  }

  private static boolean isCollision(GridPosition sStart, GridPosition sEnd) {
    if (obstacles.contains(sStart) || obstacles.contains(sEnd)) {
      return true;
    }

    if (sStart.x != sEnd.x && sStart.y != sEnd.y) {
      GridPosition s1;
      GridPosition s2;

      if (sEnd.x - sStart.x == sStart.y - sEnd.y) {
        s1 = new GridPosition(Math.min(sStart.x, sEnd.x), Math.min(sStart.y, sEnd.y));
        s2 = new GridPosition(Math.max(sStart.x, sEnd.x), Math.max(sStart.y, sEnd.y));
      } else {
        s1 = new GridPosition(Math.min(sStart.x, sEnd.x), Math.max(sStart.y, sEnd.y));
        s2 = new GridPosition(Math.max(sStart.x, sEnd.x), Math.min(sStart.y, sEnd.y));
      }

      return obstacles.contains(s1) || obstacles.contains(s2);
    }

    return false;
  }

  private static List<GridPosition> getOpenNeighbors(GridPosition s) {
    List<GridPosition> ret = new ArrayList<>();

    for (int xMove = -1; xMove <= 1; xMove++) {
      for (int yMove = -1; yMove <= 1; yMove++) {
        GridPosition sNext = new GridPosition(s.x + xMove, s.y + yMove);
        if (!obstacles.contains(sNext)
            && sNext.x >= 0
            && sNext.x < NODE_X
            && sNext.y >= 0
            && sNext.y < NODE_Y) {
          ret.add(sNext);
        }
      }
    }
    return ret;
  }

  private static List<GridPosition> getAllNeighbors(GridPosition s) {
    List<GridPosition> ret = new ArrayList<>();

    for (int xMove = -1; xMove <= 1; xMove++) {
      for (int yMove = -1; yMove <= 1; yMove++) {
        GridPosition sNext = new GridPosition(s.x + xMove, s.y + yMove);
        if (sNext.x >= 0 && sNext.x < NODE_X && sNext.y >= 0 && sNext.y < NODE_Y) {
          ret.add(sNext);
        }
      }
    }
    return ret;
  }

  private static Pair<Double, Double> key(GridPosition s) {
    if (g.get(s) > rhs.get(s)) {
      return Pair.of(rhs.get(s) + eps * heuristic(sStart, s), rhs.get(s));
    } else {
      return Pair.of(g.get(s) + heuristic(sStart, s), g.get(s));
    }
  }

  private static Pair<GridPosition, Pair<Double, Double>> topKey() {
    Map.Entry<GridPosition, Pair<Double, Double>> min = null;
    for (var entry : open.entrySet()) {
      if (min == null || comparePair(entry.getValue(), min.getValue()) < 0) {
        min = entry;
      }
    }

    if (min == null) {
      return null;
    }

    return Pair.of(min.getKey(), min.getValue());
  }

  private static double heuristic(GridPosition sStart, GridPosition sGoal) {
    return Math.hypot(sGoal.x - sStart.x, sGoal.y - sStart.y);
  }

  private static int comparePair(Pair<Double, Double> a, Pair<Double, Double> b) {
    int first = Double.compare(a.getFirst(), b.getFirst());
    if (first == 0) {
      return Double.compare(a.getSecond(), b.getSecond());
    } else {
      return first;
    }
  }

  public static GridPosition getGridPos(Translation2d pos) {
    int x = (int) Math.floor(pos.getX() / NODE_SIZE);
    int y = (int) Math.floor(pos.getY() / NODE_SIZE);

    return new GridPosition(x, y);
  }

  private static Translation2d gridPosToTranslation2d(GridPosition pos) {
    return new Translation2d(pos.x * NODE_SIZE, pos.y * NODE_SIZE);
  }

  public static class GridPosition implements Comparable<GridPosition> {
    public final int x;
    public final int y;

    public GridPosition(int x, int y) {
      this.x = x;
      this.y = y;
    }

    @Override
    public int hashCode() {
      return x * 1000 + y;
    }

    @Override
    public boolean equals(Object obj) {
      if (obj instanceof GridPosition) {
        var other = (GridPosition) obj;
        return x == other.x && y == other.y;
      } else {
        return false;
      }
    }

    @Override
    public int compareTo(GridPosition o) {
      if (x == o.x) {
        return Integer.compare(y, o.y);
      } else {
        return Integer.compare(x, o.x);
      }
    }

    @Override
    public String toString() {
      return "(" + x + ", " + y + ")";
    }
  }
}
