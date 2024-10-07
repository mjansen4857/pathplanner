package com.pathplanner.lib.commands;

import com.pathplanner.lib.auto.AutoBuilder;
import com.pathplanner.lib.auto.AutoBuilderException;
import com.pathplanner.lib.auto.CommandUtil;
import com.pathplanner.lib.events.EventTrigger;
import com.pathplanner.lib.events.PointTowardsZoneTrigger;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.util.PPLibTelemetry;
import edu.wpi.first.hal.FRCNetComm.tResourceType;
import edu.wpi.first.hal.HAL;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.wpilibj.DriverStation;
import edu.wpi.first.wpilibj.Filesystem;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj.event.EventLoop;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Commands;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.io.*;
import java.util.ArrayList;
import java.util.List;
import java.util.function.BooleanSupplier;

import edu.wpi.first.wpilibj2.command.button.Trigger;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

/** A command that loads and runs an autonomous routine built using PathPlanner. */
public class PathPlannerAuto extends Command {
  private static int instances = 0;

  private Command autoCommand;
  private Pose2d startingPose;

  private final EventLoop autoLoop;
  private final Timer timer;
  private boolean isRunning = false;

  /**
   * Constructs a new PathPlannerAuto command.
   *
   * @param autoName the name of the autonomous routine to load and run
   * @throws AutoBuilderException if AutoBuilder is not configured before attempting to load the
   *     autonomous routine
   */
  public PathPlannerAuto(String autoName) {
    if (!AutoBuilder.isConfigured()) {
      throw new AutoBuilderException(
          "AutoBuilder was not configured before attempting to load a PathPlannerAuto from file");
    }

    try (BufferedReader br =
        new BufferedReader(
            new FileReader(
                new File(
                    Filesystem.getDeployDirectory(), "pathplanner/autos/" + autoName + ".auto")))) {
      StringBuilder fileContentBuilder = new StringBuilder();
      String line;
      while ((line = br.readLine()) != null) {
        fileContentBuilder.append(line);
      }

      String fileContent = fileContentBuilder.toString();
      JSONObject json = (JSONObject) new JSONParser().parse(fileContent);
      initFromJson(json);
    } catch (FileNotFoundException e) {
      DriverStation.reportError(e.getMessage(), e.getStackTrace());
      autoCommand = Commands.none();
    } catch (IOException e) {
      DriverStation.reportError(
          "Failed to read file required by auto: " + autoName, e.getStackTrace());
      autoCommand = Commands.none();
    } catch (ParseException e) {
      DriverStation.reportError(
          "Failed to parse JSON in file required by auto: " + autoName, e.getStackTrace());
      autoCommand = Commands.none();
    }

    addRequirements(autoCommand.getRequirements().toArray(new Subsystem[0]));
    setName(autoName);
    PPLibTelemetry.registerHotReloadAuto(autoName, this);

    this.autoLoop = new EventLoop();
    this.timer = new Timer();

    instances++;
    HAL.report(tResourceType.kResourceType_PathPlannerAuto, instances);
  }

  /**
   * Get the starting pose of this auto, relative to a blue alliance origin. If there are no paths
   * in this auto, the starting pose will be null.
   *
   * @return The blue alliance starting pose
   */
  public Pose2d getStartingPose() {
    return startingPose;
  }

  /**
   * Create a trigger that is high when this auto is running, and low when it is not running
   * @return isRunning trigger
   */
  public Trigger isRunning() {
    return new Trigger(autoLoop, () -> isRunning);
  }

  public Trigger timeElapsed(double time) {
    return new Trigger(autoLoop, () -> timer.hasElapsed(time));
  }

  public Trigger timeRange(double startTime, double endTime) {
    return new Trigger(autoLoop, () -> timer.get() >= startTime && timer.get() <= endTime);
  }

  public Trigger event(String eventName){
    return new EventTrigger(autoLoop, eventName);
  }

  public Trigger pointTowardsZone(String zoneName){
    return new PointTowardsZoneTrigger(autoLoop, zoneName);
  }

  public Trigger condition(BooleanSupplier condition) {
    return new Trigger(autoLoop, condition);
  }

  @Override
  public void initialize() {
    autoCommand.initialize();
    timer.restart();

    isRunning = true;
    autoLoop.poll();
  }

  @Override
  public void execute() {
    autoCommand.execute();

    autoLoop.poll();
  }

  @Override
  public boolean isFinished() {
    return autoCommand.isFinished();
  }

  @Override
  public void end(boolean interrupted) {
    autoCommand.end(interrupted);
    timer.stop();

    isRunning = false;
    autoLoop.poll();
  }

  /**
   * Get a list of every path in the given auto (depth first)
   *
   * @param autoName Name of the auto to get the path group from
   * @return List of paths in the auto
   * @throws IOException if attempting to load a file that does not exist or cannot be read
   * @throws ParseException If JSON within file cannot be parsed
   */
  public static List<PathPlannerPath> getPathGroupFromAutoFile(String autoName)
          throws IOException, ParseException {
    try (BufferedReader br =
                 new BufferedReader(
                         new FileReader(
                                 new File(
                                         Filesystem.getDeployDirectory(), "pathplanner/autos/" + autoName + ".auto")))) {
      StringBuilder fileContentBuilder = new StringBuilder();
      String line;
      while ((line = br.readLine()) != null) {
        fileContentBuilder.append(line);
      }

      String fileContent = fileContentBuilder.toString();
      JSONObject json = (JSONObject) new JSONParser().parse(fileContent);
      boolean choreoAuto = json.get("choreoAuto") != null && (boolean) json.get("choreoAuto");
      return pathsFromCommandJson((JSONObject) json.get("command"), choreoAuto);
    }
  }

  /**
   * Reloads the autonomous routine with the given JSON object and updates the requirements of this
   * command.
   *
   * @param autoJson the JSON object representing the updated autonomous routine
   */
  public void hotReload(JSONObject autoJson) {
    try {
      initFromJson(autoJson);
    } catch (Exception e) {
      DriverStation.reportError("Failed to load path during hot reload", e.getStackTrace());
    }
  }

  private void initFromJson(JSONObject autoJson) throws IOException, ParseException {
    boolean choreoAuto = autoJson.get("choreoAuto") != null && (boolean) autoJson.get("choreoAuto");
    JSONObject commandJson = (JSONObject) autoJson.get("command");
    Command cmd = CommandUtil.commandFromJson(commandJson, choreoAuto);
    boolean resetOdom = autoJson.get("resetOdom") != null && (boolean) autoJson.get("resetOdom");
    List<PathPlannerPath> pathsInAuto = pathsFromCommandJson(commandJson, choreoAuto);
    if (!pathsInAuto.isEmpty()) {
      if (AutoBuilder.isHolonomic()) {
        this.startingPose =
                new Pose2d(
                        pathsInAuto.get(0).getPoint(0).position,
                        pathsInAuto.get(0).getIdealStartingState().rotation());
      } else {
        this.startingPose = pathsInAuto.get(0).getStartingDifferentialPose();
      }
    } else {
      this.startingPose = null;
    }

    if (resetOdom) {
      this.autoCommand = Commands.sequence(AutoBuilder.resetOdom(this.startingPose), cmd);
    } else {
      this.autoCommand = cmd;
    }
  }

  private static List<PathPlannerPath> pathsFromCommandJson(
      JSONObject commandJson, boolean choreoPaths) throws IOException, ParseException {
    List<PathPlannerPath> paths = new ArrayList<>();

    String type = (String) commandJson.get("type");
    JSONObject data = (JSONObject) commandJson.get("data");

    if (type.equals("path")) {
      String pathName = (String) data.get("pathName");
      if (choreoPaths) {
        paths.add(PathPlannerPath.fromChoreoTrajectory(pathName));
      } else {
        paths.add(PathPlannerPath.fromPathFile(pathName));
      }
    } else if (type.equals("sequential")
        || type.equals("parallel")
        || type.equals("race")
        || type.equals("deadline")) {
      for (var cmdJson : (JSONArray) data.get("commands")) {
        paths.addAll(pathsFromCommandJson((JSONObject) cmdJson, choreoPaths));
      }
    }

    return paths;
  }
}
