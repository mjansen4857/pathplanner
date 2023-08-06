package com.pathplanner.lib.util;

import com.pathplanner.lib.auto.PathPlannerAuto;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.path.PathPoint;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.networktables.*;
import edu.wpi.first.wpilibj.DriverStation;
import edu.wpi.first.wpilibj.Filesystem;
import edu.wpi.first.wpilibj.RobotBase;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.util.*;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

public class PPLibTelemetry {
  private static boolean compMode = false;

  private static final DoubleArrayPublisher velPub =
      NetworkTableInstance.getDefault().getDoubleArrayTopic("/PathPlanner/vel").publish();
  private static final DoublePublisher inaccuracyPub =
      NetworkTableInstance.getDefault().getDoubleTopic("/PathPlanner/inaccuracy").publish();
  private static final DoubleArrayPublisher posePub =
      NetworkTableInstance.getDefault().getDoubleArrayTopic("/PathPlanner/currentPose").publish();
  private static final DoubleArrayPublisher pathPub =
      NetworkTableInstance.getDefault().getDoubleArrayTopic("/PathPlanner/currentPath").publish();
  private static final DoubleArrayPublisher lookaheadPub =
      NetworkTableInstance.getDefault().getDoubleArrayTopic("/PathPlanner/lookahead").publish();

  private static final Map<String, List<PathPlannerPath>> hotReloadPaths = new HashMap<>();
  private static final Map<String, List<PathPlannerAuto>> hotReloadAutos = new HashMap<>();
  private static NetworkTableListener hotReloadPathListener = null;
  private static NetworkTableListener hotReloadAutoListener = null;

  public static void enableCompetitionMode() {
    compMode = true;
  }

  public static void setVelocities(
      double actualVel, double commandedVel, double actualAngVel, double commandedAngVel) {
    if (!compMode) {
      velPub.set(new double[] {actualVel, commandedVel, actualAngVel, commandedAngVel});
    }
  }

  public static void setPathInaccuracy(double inaccuracy) {
    if (!compMode) {
      inaccuracyPub.set(inaccuracy);
    }
  }

  public static void setCurrentPose(Pose2d pose) {
    if (!compMode) {
      posePub.set(new double[] {pose.getX(), pose.getY(), pose.getRotation().getDegrees()});
    }
  }

  public static void setCurrentPath(PathPlannerPath path) {
    if (!compMode) {
      double[] arr = new double[path.numPoints() * 2];

      int ndx = 0;
      for (PathPoint p : path.getAllPathPoints()) {
        Translation2d pos = p.position;
        arr[ndx] = pos.getX();
        arr[ndx + 1] = pos.getY();
        ndx += 2;
      }

      pathPub.set(arr);
    }
  }

  public static void setLookahead(Translation2d lookahead) {
    if (!compMode) {
      lookaheadPub.set(new double[] {lookahead.getX(), lookahead.getY()});
    }
  }

  public static void registerHotReloadPath(String pathName, PathPlannerPath path) {
    if (!compMode) {
      ensureHotReloadListenersInitialized();
      if (!hotReloadPaths.containsKey(pathName)) {
        hotReloadPaths.put(pathName, new ArrayList<>());
      }

      hotReloadPaths.get(pathName).add(path);
    }
  }

  public static void registerHotReloadAuto(String autoName, PathPlannerAuto auto) {
    if (!compMode) {
      ensureHotReloadListenersInitialized();
      if (!hotReloadAutos.containsKey(autoName)) {
        hotReloadAutos.put(autoName, new ArrayList<>());
      }

      hotReloadAutos.get(autoName).add(auto);
    }
  }

  private static void ensureHotReloadListenersInitialized() {
    if (hotReloadPathListener == null) {
      hotReloadPathListener =
          NetworkTableListener.createListener(
              NetworkTableInstance.getDefault()
                  .getStringTopic("/PathPlanner/HotReload/hotReloadPath"),
              EnumSet.of(NetworkTableEvent.Kind.kValueRemote),
              PPLibTelemetry::handlePathHotReloadEvent);
    }
    if (hotReloadAutoListener == null) {
      hotReloadAutoListener =
          NetworkTableListener.createListener(
              NetworkTableInstance.getDefault()
                  .getStringTopic("/PathPlanner/HotReload/hotReloadAuto"),
              EnumSet.of(NetworkTableEvent.Kind.kValueRemote),
              PPLibTelemetry::handleAutoHotReloadEvent);
    }
  }

  private static void handlePathHotReloadEvent(NetworkTableEvent event) {
    if (!compMode) {
      if (DriverStation.isEnabled()) {
        DriverStation.reportWarning("Ignoring path hot reload, robot is enabled", false);
        return;
      }

      try {
        String jsonStr = event.valueData.value.getString();

        JSONObject json = (JSONObject) new JSONParser().parse(jsonStr);
        String name = (String) json.get("name");
        JSONObject pathJson = (JSONObject) json.get("path");

        if (hotReloadPaths.containsKey(name)) {
          for (PathPlannerPath path : hotReloadPaths.get(name)) {
            path.hotReload(pathJson);
          }
        }

        if (RobotBase.isReal()) {
          File pathFile =
              new File(Filesystem.getDeployDirectory(), "pathplanner/paths/" + name + ".path");

          try (FileWriter writer = new FileWriter(pathFile)) {
            writer.write(pathJson.toJSONString());
            writer.flush();
          } catch (IOException e) {
            DriverStation.reportWarning(
                "Failed to save updated path file contents, please re-deploy code", false);
          }
        }
      } catch (Exception e) {
        // Ignore
      }
    }
  }

  private static void handleAutoHotReloadEvent(NetworkTableEvent event) {
    System.out.println("hot reload auto");
    if (!compMode) {
      if (DriverStation.isEnabled()) {
        DriverStation.reportWarning("Ignoring auto hot reload, robot is enabled", false);
        return;
      }

      try {
        String jsonStr = event.valueData.value.getString();

        JSONObject json = (JSONObject) new JSONParser().parse(jsonStr);
        String name = (String) json.get("name");
        JSONObject autoJson = (JSONObject) json.get("auto");

        if (hotReloadAutos.containsKey(name)) {
          for (PathPlannerAuto auto : hotReloadAutos.get(name)) {
            auto.hotReload(autoJson);
          }
        }

        if (RobotBase.isReal()) {
          File pathFile =
              new File(Filesystem.getDeployDirectory(), "pathplanner/autos/" + name + ".auto");

          try (FileWriter writer = new FileWriter(pathFile)) {
            writer.write(autoJson.toJSONString());
            writer.flush();
          } catch (IOException e) {
            DriverStation.reportWarning(
                "Failed to save updated auto file contents, please re-deploy code", false);
          }
        }
      } catch (Exception e) {
        // Ignore
      }
    }
  }
}
