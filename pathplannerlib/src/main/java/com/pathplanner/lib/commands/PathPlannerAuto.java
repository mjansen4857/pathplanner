package com.pathplanner.lib.commands;

import static edu.wpi.first.units.Units.Meters;
import static edu.wpi.first.units.Units.Seconds;

import com.pathplanner.lib.auto.AutoBuilder;
import com.pathplanner.lib.auto.AutoBuilderException;
import com.pathplanner.lib.auto.CommandUtil;
import com.pathplanner.lib.events.EventTrigger;
import com.pathplanner.lib.events.PointTowardsZoneTrigger;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.util.FileVersionException;
import com.pathplanner.lib.util.FlippingUtil;
import com.pathplanner.lib.util.PPLibTelemetry;
import edu.wpi.first.hal.FRCNetComm.tResourceType;
import edu.wpi.first.hal.HAL;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.units.measure.Distance;
import edu.wpi.first.units.measure.Time;
import edu.wpi.first.wpilibj.DriverStation;
import edu.wpi.first.wpilibj.Filesystem;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj.event.EventLoop;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Commands;
import edu.wpi.first.wpilibj2.command.button.Trigger;
import java.io.*;
import java.util.ArrayList;
import java.util.List;
import java.util.function.BooleanSupplier;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

/** A command that loads and runs an autonomous routine built using PathPlanner. */
public class PathPlannerAuto extends Command {
  /** The currently running path name. Used to handle activePath triggers */
  public static String currentPathName = "";

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

      String version = json.get("version").toString();
      String[] versions = version.split("\\.");

      if (!versions[0].equals("2025")) {
        throw new FileVersionException(version, "2025.X", autoName + ".auto");
      }

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
    } catch (FileVersionException e) {
      DriverStation.reportError(
          "Failed to load auto: " + autoName + ". " + e.getMessage(), e.getStackTrace());
      autoCommand = Commands.none();
    }

    addRequirements(autoCommand.getRequirements());
    setName(autoName);
    PPLibTelemetry.registerHotReloadAuto(autoName, this);

    this.autoLoop = new EventLoop();
    this.timer = new Timer();

    instances++;
    HAL.report(tResourceType.kResourceType_PathPlannerAuto, instances);
  }

  /**
   * Create a PathPlannerAuto from a custom command
   *
   * @param autoCommand The command this auto should run
   * @param startingPose The starting pose of the auto. Only used for the getStartingPose method
   */
  public PathPlannerAuto(Command autoCommand, Pose2d startingPose) {
    this.autoCommand = autoCommand;
    this.startingPose = startingPose;

    addRequirements(autoCommand.getRequirements());

    this.autoLoop = new EventLoop();
    this.timer = new Timer();

    instances++;
    HAL.report(tResourceType.kResourceType_PathPlannerAuto, instances);
  }

  /**
   * Create a PathPlannerAuto from a custom command
   *
   * @param autoCommand The command this auto should run
   */
  public PathPlannerAuto(Command autoCommand) {
    this(autoCommand, Pose2d.kZero);
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
   *
   * @return isRunning trigger
   */
  public Trigger isRunning() {
    return condition(() -> isRunning);
  }

  /**
   * Trigger that is high when the given time has elapsed
   *
   * @param time The amount of time this auto should run before the trigger is activated
   * @return timeElapsed trigger
   */
  public Trigger timeElapsed(double time) {
    return condition(() -> timer.hasElapsed(time));
  }

  /**
   * Trigger that is high when the given time has elapsed
   *
   * @param time The amount of time this auto should run before the trigger is activated
   * @return timeElapsed trigger
   */
  public Trigger timeElapsed(Time time) {
    return timeElapsed(time.in(Seconds));
  }

  /**
   * Trigger that is high when within a range of time since the start of this auto
   *
   * @param startTime The starting time of the range
   * @param endTime The ending time of the range
   * @return timeRange trigger
   */
  public Trigger timeRange(double startTime, double endTime) {
    return condition(() -> timer.get() >= startTime && timer.get() <= endTime);
  }

  /**
   * Trigger that is high when within a range of time since the start of this auto
   *
   * @param startTime The starting time of the range
   * @param endTime The ending time of the range
   * @return timeRange trigger
   */
  public Trigger timeRange(Time startTime, Time endTime) {
    return timeRange(startTime.in(Seconds), endTime.in(Seconds));
  }

  /**
   * Create an EventTrigger that will be polled by this auto instead of globally across all path
   * following commands
   *
   * @param eventName The event name that controls this trigger
   * @return EventTrigger for this auto
   */
  public Trigger event(String eventName) {
    return new EventTrigger(autoLoop, eventName);
  }

  /**
   * Create a PointTowardsZoneTrigger that will be polled by this auto instead of globally across
   * all path following commands
   *
   * @param zoneName The point towards zone name that controls this trigger
   * @return PointTowardsZoneTrigger for this auto
   */
  public Trigger pointTowardsZone(String zoneName) {
    return new PointTowardsZoneTrigger(autoLoop, zoneName);
  }

  /**
   * Create a trigger that is high when a certain path is being followed
   *
   * @param pathName The name of the path to check for
   * @return activePath trigger
   */
  public Trigger activePath(String pathName) {
    return condition(() -> pathName.equals(currentPathName));
  }

  /**
   * Create a trigger that is high when near a given field position. This field position is not
   * automatically flipped
   *
   * @param fieldPosition The target field position
   * @param toleranceMeters The position tolerance, in meters. The trigger will be high when within
   *     this distance from the target position
   * @return nearFieldPosition trigger
   */
  public Trigger nearFieldPosition(Translation2d fieldPosition, double toleranceMeters) {
    return condition(
        () ->
            AutoBuilder.getCurrentPose().getTranslation().getDistance(fieldPosition)
                <= toleranceMeters);
  }

  /**
   * Create a trigger that is high when near a given field position. This field position is not
   * automatically flipped
   *
   * @param fieldPosition The target field position
   * @param tolerance The position tolerance. The trigger will be high when within this distance
   *     from the target position
   * @return nearFieldPosition trigger
   */
  public Trigger nearFieldPosition(Translation2d fieldPosition, Distance tolerance) {
    return nearFieldPosition(fieldPosition, tolerance.in(Meters));
  }

  /**
   * Create a trigger that is high when near a given field position. This field position will be
   * automatically flipped
   *
   * @param blueFieldPosition The target field position if on the blue alliance
   * @param toleranceMeters The position tolerance, in meters. The trigger will be high when within
   *     this distance from the target position
   * @return nearFieldPositionAutoFlipped trigger
   */
  public Trigger nearFieldPositionAutoFlipped(
      Translation2d blueFieldPosition, double toleranceMeters) {
    Translation2d redFieldPosition = FlippingUtil.flipFieldPosition(blueFieldPosition);
    return condition(
        () -> {
          if (AutoBuilder.shouldFlip()) {
            return AutoBuilder.getCurrentPose().getTranslation().getDistance(redFieldPosition)
                <= toleranceMeters;
          } else {
            return AutoBuilder.getCurrentPose().getTranslation().getDistance(blueFieldPosition)
                <= toleranceMeters;
          }
        });
  }

  /**
   * Create a trigger that is high when near a given field position. This field position will be
   * automatically flipped
   *
   * @param blueFieldPosition The target field position if on the blue alliance
   * @param tolerance The position tolerance. The trigger will be high when within this distance
   *     from the target position
   * @return nearFieldPositionAutoFlipped trigger
   */
  public Trigger nearFieldPositionAutoFlipped(Translation2d blueFieldPosition, Distance tolerance) {
    return nearFieldPositionAutoFlipped(blueFieldPosition, tolerance.in(Meters));
  }

  /**
   * Create a trigger that will be high when the robot is within a given area on the field. These
   * positions will not be automatically flipped
   *
   * @param boundingBoxMin The minimum position of the bounding box for the target field area. The X
   *     and Y coordinates of this position should be less than the max position.
   * @param boundingBoxMax The maximum position of the bounding box for the target field area. The X
   *     and Y coordinates of this position should be greater than the min position.
   * @return inFieldArea trigger
   */
  public Trigger inFieldArea(Translation2d boundingBoxMin, Translation2d boundingBoxMax) {
    if (boundingBoxMin.getX() >= boundingBoxMax.getX()
        || boundingBoxMin.getY() >= boundingBoxMax.getY()) {
      throw new IllegalArgumentException(
          "Minimum bounding box position must have X and Y coordinates less than the maximum bounding box position");
    }

    return condition(
        () -> {
          Pose2d currentPose = AutoBuilder.getCurrentPose();
          return currentPose.getX() >= boundingBoxMin.getX()
              && currentPose.getY() >= boundingBoxMin.getY()
              && currentPose.getX() <= boundingBoxMax.getX()
              && currentPose.getY() <= boundingBoxMax.getY();
        });
  }

  /**
   * Create a trigger that will be high when the robot is within a given area on the field. These
   * positions will be automatically flipped
   *
   * @param blueBoundingBoxMin The minimum position of the bounding box for the target field area if
   *     on the blue alliance. The X and Y coordinates of this position should be less than the max
   *     position.
   * @param blueBoundingBoxMax The maximum position of the bounding box for the target field area if
   *     on the blue alliance. The X and Y coordinates of this position should be greater than the
   *     min position.
   * @return inFieldAreaAutoFlipped trigger
   */
  public Trigger inFieldAreaAutoFlipped(
      Translation2d blueBoundingBoxMin, Translation2d blueBoundingBoxMax) {
    if (blueBoundingBoxMin.getX() >= blueBoundingBoxMax.getX()
        || blueBoundingBoxMin.getY() >= blueBoundingBoxMax.getY()) {
      throw new IllegalArgumentException(
          "Minimum bounding box position must have X and Y coordinates less than the maximum bounding box position");
    }

    Translation2d redBoundingBoxMin = FlippingUtil.flipFieldPosition(blueBoundingBoxMin);
    Translation2d redBoundingBoxMax = FlippingUtil.flipFieldPosition(blueBoundingBoxMax);

    return condition(
        () -> {
          Pose2d currentPose = AutoBuilder.getCurrentPose();
          if (AutoBuilder.shouldFlip()) {
            return currentPose.getX() >= blueBoundingBoxMin.getX()
                && currentPose.getY() >= blueBoundingBoxMin.getY()
                && currentPose.getX() <= blueBoundingBoxMax.getX()
                && currentPose.getY() <= blueBoundingBoxMax.getY();
          } else {
            return currentPose.getX() >= redBoundingBoxMin.getX()
                && currentPose.getY() >= redBoundingBoxMin.getY()
                && currentPose.getX() <= redBoundingBoxMax.getX()
                && currentPose.getY() <= redBoundingBoxMax.getY();
          }
        });
  }

  /**
   * Create a trigger with a custom condition. This will be polled by this auto's event loop so that
   * its condition is only polled when this auto is running.
   *
   * @param condition The condition represented by this trigger
   * @return Custom condition trigger
   */
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

  private void initFromJson(JSONObject autoJson)
      throws IOException, ParseException, FileVersionException {
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
