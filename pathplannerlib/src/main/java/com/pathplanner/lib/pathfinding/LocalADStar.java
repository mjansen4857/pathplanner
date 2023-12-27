package com.pathplanner.lib.pathfinding;

import com.pathplanner.lib.path.*;
import com.pathplanner.lib.util.GeometryUtil;
import edu.wpi.first.math.Pair;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.wpilibj.Filesystem;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.*;
import java.util.concurrent.locks.ReadWriteLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

/**
 * Implementation of AD* running locally in a background thread
 *
 * <p>I would like to apologize to anyone trying to understand this code. The implementation I
 * translated it from was much worse.
 */
public class LocalADStar implements Pathfinder {
  private static final double SMOOTHING_ANCHOR_PCT = 0.8;
  private static final double SMOOTHING_CONTROL_PCT = 0.33;
  private static final double EPS = 2.5;

  private double fieldLength = 16.54;
  private double fieldWidth = 8.02;

  private double nodeSize = 0.2;

  private int nodesX = (int) Math.ceil(fieldLength / nodeSize);
  private int nodesY = (int) Math.ceil(fieldWidth / nodeSize);

  private final HashMap<GridPosition, Double> g = new HashMap<>();
  private final HashMap<GridPosition, Double> rhs = new HashMap<>();
  private final HashMap<GridPosition, Pair<Double, Double>> open = new HashMap<>();
  private final HashMap<GridPosition, Pair<Double, Double>> incons = new HashMap<>();
  private final Set<GridPosition> closed = new HashSet<>();
  private final Set<GridPosition> staticObstacles = new HashSet<>();
  private final Set<GridPosition> dynamicObstacles = new HashSet<>();
  private final Set<GridPosition> requestObstacles = new HashSet<>();

  private GridPosition requestStart;
  private Translation2d requestRealStartPos;
  private GridPosition requestGoal;
  private Translation2d requestRealGoalPos;

  private double eps;

  private final Thread planningThread;
  private boolean requestMinor = true;
  private boolean requestMajor = true;
  private boolean requestReset = true;
  private boolean newPathAvailable = false;

  private final ReadWriteLock pathLock = new ReentrantReadWriteLock();
  private final ReadWriteLock requestLock = new ReentrantReadWriteLock();

  private List<PathPoint> currentPathPoints = new ArrayList<>();
  private List<GridPosition> currentPathFull = new ArrayList<>();

  /** Create a new pathfinder that runs AD* locally in a background thread */
  public LocalADStar() {
    planningThread = new Thread(this::runThread);

    requestStart = new GridPosition(0, 0);
    requestRealStartPos = new Translation2d(0, 0);
    requestGoal = new GridPosition(0, 0);
    requestRealGoalPos = new Translation2d(0, 0);

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

        nodeSize = ((Number) json.get("nodeSizeMeters")).doubleValue();
        JSONArray grid = (JSONArray) json.get("grid");
        nodesY = grid.size();
        for (int row = 0; row < grid.size(); row++) {
          JSONArray rowArray = (JSONArray) grid.get(row);
          if (row == 0) {
            nodesX = rowArray.size();
          }
          for (int col = 0; col < rowArray.size(); col++) {
            boolean isObstacle = (boolean) rowArray.get(col);
            if (isObstacle) {
              staticObstacles.add(new GridPosition(col, row));
            }
          }
        }

        JSONObject fieldSize = (JSONObject) json.get("field_size");
        fieldLength = ((Number) fieldSize.get("x")).doubleValue();
        fieldWidth = ((Number) fieldSize.get("y")).doubleValue();
      } catch (Exception e) {
        // Do nothing, use defaults
      }
    }

    requestObstacles.clear();
    requestObstacles.addAll(staticObstacles);
    requestObstacles.addAll(dynamicObstacles);

    requestReset = true;
    requestMajor = true;
    requestMinor = true;

    newPathAvailable = false;

    planningThread.setDaemon(true);
    planningThread.setName("ADStar Planning Thread");
    planningThread.start();
  }

  /**
   * Get if a new path has been calculated since the last time a path was retrieved
   *
   * @return True if a new path is available
   */
  @Override
  public boolean isNewPathAvailable() {
    return newPathAvailable;
  }

  /**
   * Get the most recently calculated path
   *
   * @param constraints The path constraints to use when creating the path
   * @param goalEndState The goal end state to use when creating the path
   * @return The PathPlannerPath created from the points calculated by the pathfinder
   */
  @Override
  public PathPlannerPath getCurrentPath(PathConstraints constraints, GoalEndState goalEndState) {
    List<PathPoint> pathPoints;

    pathLock.readLock().lock();
    pathPoints = new ArrayList<>(currentPathPoints);
    pathLock.readLock().unlock();

    newPathAvailable = false;

    if (currentPathPoints.isEmpty()) {
      // Not enough points. Something got borked somewhere
      return null;
    }

    return PathPlannerPath.fromPathPoints(pathPoints, constraints, goalEndState);
  }

  /**
   * Set the start position to pathfind from
   *
   * @param startPosition Start position on the field. If this is within an obstacle it will be
   *     moved to the nearest non-obstacle node.
   */
  @Override
  public void setStartPosition(Translation2d startPosition) {
    GridPosition startPos = findClosestNonObstacle(getGridPos(startPosition), requestObstacles);

    if (startPos != null && !startPos.equals(requestStart)) {
      requestLock.writeLock().lock();
      requestStart = startPos;
      requestRealStartPos = startPosition;

      requestMinor = true;
      requestLock.writeLock().unlock();
    }
  }

  /**
   * Set the goal position to pathfind to
   *
   * @param goalPosition Goal position on the field. f this is within an obstacle it will be moved
   *     to the nearest non-obstacle node.
   */
  @Override
  public void setGoalPosition(Translation2d goalPosition) {
    GridPosition gridPos = findClosestNonObstacle(getGridPos(goalPosition), requestObstacles);

    if (gridPos != null) {
      requestLock.writeLock().lock();
      requestGoal = gridPos;
      requestRealGoalPos = goalPosition;

      requestMinor = true;
      requestMajor = true;
      requestReset = true;
      requestLock.writeLock().unlock();
    }
  }

  /**
   * Set the dynamic obstacles that should be avoided while pathfinding.
   *
   * @param obs A List of Translation2d pairs representing obstacles. Each Translation2d represents
   *     opposite corners of a bounding box.
   * @param currentRobotPos The current position of the robot. This is needed to change the start
   *     position of the path if the robot is now within an obstacle.
   */
  @Override
  public void setDynamicObstacles(
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

    dynamicObstacles.clear();
    dynamicObstacles.addAll(newObs);
    requestLock.writeLock().lock();
    requestObstacles.clear();
    requestObstacles.addAll(staticObstacles);
    requestObstacles.addAll(dynamicObstacles);
    requestLock.writeLock().unlock();

    pathLock.readLock().lock();
    boolean recalculate = false;
    for (GridPosition pos : currentPathFull) {
      if (requestObstacles.contains(pos)) {
        recalculate = true;
        break;
      }
    }
    pathLock.readLock().unlock();

    if (recalculate) {
      setStartPosition(currentRobotPos);
      setGoalPosition(requestRealGoalPos);
    }
  }

  @SuppressWarnings("BusyWait")
  private void runThread() {
    while (true) {
      try {
        requestLock.readLock().lock();
        boolean reset = requestReset;
        boolean minor = requestMinor;
        boolean major = requestMajor;
        GridPosition start = requestStart;
        Translation2d realStart = requestRealStartPos;
        GridPosition goal = requestGoal;
        Translation2d realGoal = requestRealGoalPos;
        Set<GridPosition> obstacles = new HashSet<>(requestObstacles);

        // Change the request booleans based on what will be done this loop
        if (reset) {
          requestReset = false;
        }

        if (minor) {
          requestMinor = false;
        } else if (major && (eps - 0.5) <= 1.0) {
          requestMajor = false;
        }
        requestLock.readLock().unlock();

        if (reset || minor || major) {
          doWork(reset, minor, major, start, goal, realStart, realGoal, obstacles);
        } else {
          try {
            Thread.sleep(10);
          } catch (InterruptedException e) {
            throw new RuntimeException(e);
          }
        }
      } catch (Exception e) {
        // Something messed up. Reset and hope for the best
        requestLock.writeLock().lock();
        requestReset = true;
        requestLock.writeLock().unlock();
      }
    }
  }

  private void doWork(
      boolean needsReset,
      boolean doMinor,
      boolean doMajor,
      GridPosition sStart,
      GridPosition sGoal,
      Translation2d realStartPos,
      Translation2d realGoalPos,
      Set<GridPosition> obstacles) {
    if (needsReset) {
      reset(sStart, sGoal);
    }

    if (doMinor) {
      computeOrImprovePath(sStart, sGoal, obstacles);

      List<GridPosition> pathPositions = extractPath(sStart, sGoal, obstacles);
      List<PathPoint> pathPoints =
          createPathPoints(pathPositions, realStartPos, realGoalPos, obstacles);

      pathLock.writeLock().lock();
      currentPathFull = pathPositions;
      currentPathPoints = pathPoints;
      pathLock.writeLock().unlock();

      newPathAvailable = true;
    } else if (doMajor) {
      if (eps > 1.0) {
        eps -= 0.5;
        open.putAll(incons);

        open.replaceAll((s, v) -> key(s, sStart));
        closed.clear();
        computeOrImprovePath(sStart, sGoal, obstacles);

        List<GridPosition> pathPositions = extractPath(sStart, sGoal, obstacles);
        List<PathPoint> pathPoints =
            createPathPoints(pathPositions, realStartPos, realGoalPos, obstacles);

        pathLock.writeLock().lock();
        currentPathFull = pathPositions;
        currentPathPoints = pathPoints;
        pathLock.writeLock().unlock();

        newPathAvailable = true;
      }
    }
  }

  private List<GridPosition> extractPath(
      GridPosition sStart, GridPosition sGoal, Set<GridPosition> obstacles) {
    if (sGoal.equals(sStart)) {
      return new ArrayList<>();
    }

    List<GridPosition> path = new ArrayList<>();
    path.add(sStart);

    var s = sStart;

    for (int k = 0; k < 200; k++) {
      HashMap<GridPosition, Double> gList = new HashMap<>();

      for (GridPosition x : getOpenNeighbors(s, obstacles)) {
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

    return path;
  }

  private List<PathPoint> createPathPoints(
      List<GridPosition> path,
      Translation2d realStartPos,
      Translation2d realGoalPos,
      Set<GridPosition> obstacles) {
    if (path.isEmpty()) {
      return new ArrayList<>();
    }

    List<GridPosition> simplifiedPath = new ArrayList<>();
    simplifiedPath.add(path.get(0));
    for (int i = 1; i < path.size() - 1; i++) {
      if (!walkable(simplifiedPath.get(simplifiedPath.size() - 1), path.get(i + 1), obstacles)) {
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

    int numSegments = (bezierPoints.size() - 1) / 3;
    List<PathPoint> pathPoints =
        new ArrayList<>((int) Math.ceil(numSegments / PathSegment.RESOLUTION));

    for (int i = 0; i < numSegments; i++) {
      int iOffset = i * 3;

      Translation2d p1 = bezierPoints.get(iOffset);
      Translation2d p2 = bezierPoints.get(iOffset + 1);
      Translation2d p3 = bezierPoints.get(iOffset + 2);
      Translation2d p4 = bezierPoints.get(iOffset + 3);

      double resolution = PathSegment.RESOLUTION;
      if (p1.getDistance(p4) <= 1.0) {
        resolution = 0.2;
      }

      for (double t = 0.0; t < 1.0; t += resolution) {
        pathPoints.add(new PathPoint(GeometryUtil.cubicLerp(p1, p2, p3, p4, t)));
      }
    }
    pathPoints.add(new PathPoint(bezierPoints.get(bezierPoints.size() - 1)));

    return pathPoints;
  }

  private GridPosition findClosestNonObstacle(GridPosition pos, Set<GridPosition> obstacles) {
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
        if (!visited.contains(neighbor) && !queue.contains(neighbor)) {
          queue.add(neighbor);
        }
      }
    }
    return null;
  }

  private boolean walkable(GridPosition s1, GridPosition s2, Set<GridPosition> obstacles) {
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

  private void reset(GridPosition sStart, GridPosition sGoal) {
    g.clear();
    rhs.clear();
    open.clear();
    incons.clear();
    closed.clear();

    for (int x = 0; x < nodesX; x++) {
      for (int y = 0; y < nodesY; y++) {
        g.put(new GridPosition(x, y), Double.POSITIVE_INFINITY);
        rhs.put(new GridPosition(x, y), Double.POSITIVE_INFINITY);
      }
    }

    rhs.put(sGoal, 0.0);

    eps = EPS;

    open.put(sGoal, key(sGoal, sStart));
  }

  private void computeOrImprovePath(
      GridPosition sStart, GridPosition sGoal, Set<GridPosition> obstacles) {
    while (true) {
      var sv = topKey();
      if (sv == null) {
        break;
      }
      var s = sv.getFirst();
      var v = sv.getSecond();

      if (comparePair(v, key(sStart, sStart)) >= 0 && rhs.get(sStart).equals(g.get(sStart))) {
        break;
      }

      open.remove(s);

      if (g.get(s) > rhs.get(s)) {
        g.put(s, rhs.get(s));
        closed.add(s);

        for (GridPosition sn : getOpenNeighbors(s, obstacles)) {
          updateState(sn, sStart, sGoal, obstacles);
        }
      } else {
        g.put(s, Double.POSITIVE_INFINITY);
        for (GridPosition sn : getOpenNeighbors(s, obstacles)) {
          updateState(sn, sStart, sGoal, obstacles);
        }
        updateState(s, sStart, sGoal, obstacles);
      }
    }
  }

  private void updateState(
      GridPosition s, GridPosition sStart, GridPosition sGoal, Set<GridPosition> obstacles) {
    if (!s.equals(sGoal)) {
      rhs.put(s, Double.POSITIVE_INFINITY);

      for (GridPosition x : getOpenNeighbors(s, obstacles)) {
        rhs.put(s, Math.min(rhs.get(s), g.get(x) + cost(s, x, obstacles)));
      }
    }

    open.remove(s);

    if (!g.get(s).equals(rhs.get(s))) {
      if (!closed.contains(s)) {
        open.put(s, key(s, sStart));
      } else {
        incons.put(s, Pair.of(0.0, 0.0));
      }
    }
  }

  private double cost(GridPosition sStart, GridPosition sGoal, Set<GridPosition> obstacles) {
    if (isCollision(sStart, sGoal, obstacles)) {
      return Double.POSITIVE_INFINITY;
    }

    return heuristic(sStart, sGoal);
  }

  private boolean isCollision(GridPosition sStart, GridPosition sEnd, Set<GridPosition> obstacles) {
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

  private List<GridPosition> getOpenNeighbors(GridPosition s, Set<GridPosition> obstacles) {
    List<GridPosition> ret = new ArrayList<>();

    for (int xMove = -1; xMove <= 1; xMove++) {
      for (int yMove = -1; yMove <= 1; yMove++) {
        GridPosition sNext = new GridPosition(s.x + xMove, s.y + yMove);
        if (!obstacles.contains(sNext)
            && sNext.x >= 0
            && sNext.x < nodesX
            && sNext.y >= 0
            && sNext.y < nodesY) {
          ret.add(sNext);
        }
      }
    }
    return ret;
  }

  private List<GridPosition> getAllNeighbors(GridPosition s) {
    List<GridPosition> ret = new ArrayList<>();

    for (int xMove = -1; xMove <= 1; xMove++) {
      for (int yMove = -1; yMove <= 1; yMove++) {
        GridPosition sNext = new GridPosition(s.x + xMove, s.y + yMove);
        if (sNext.x >= 0 && sNext.x < nodesX && sNext.y >= 0 && sNext.y < nodesY) {
          ret.add(sNext);
        }
      }
    }
    return ret;
  }

  private Pair<Double, Double> key(GridPosition s, GridPosition sStart) {
    if (g.get(s) > rhs.get(s)) {
      return Pair.of(rhs.get(s) + eps * heuristic(sStart, s), rhs.get(s));
    } else {
      return Pair.of(g.get(s) + heuristic(sStart, s), g.get(s));
    }
  }

  private Pair<GridPosition, Pair<Double, Double>> topKey() {
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

  private double heuristic(GridPosition sStart, GridPosition sGoal) {
    return Math.hypot(sGoal.x - sStart.x, sGoal.y - sStart.y);
  }

  private int comparePair(Pair<Double, Double> a, Pair<Double, Double> b) {
    int first = Double.compare(a.getFirst(), b.getFirst());
    if (first == 0) {
      return Double.compare(a.getSecond(), b.getSecond());
    } else {
      return first;
    }
  }

  private GridPosition getGridPos(Translation2d pos) {
    int x = (int) Math.floor(pos.getX() / nodeSize);
    int y = (int) Math.floor(pos.getY() / nodeSize);

    return new GridPosition(x, y);
  }

  private Translation2d gridPosToTranslation2d(GridPosition pos) {
    return new Translation2d(
        (pos.x * nodeSize) + (nodeSize / 2.0), (pos.y * nodeSize) + (nodeSize / 2.0));
  }

  /** Represents a node in the pathfinding grid */
  public static class GridPosition implements Comparable<GridPosition> {
    /** X index in the grid */
    public final int x;
    /** Y index in the grid */
    public final int y;

    /**
     * Create a node within the pathfinding grid
     *
     * @param x X index in the grid
     * @param y Y index in the grid
     */
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
