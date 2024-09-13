package com.pathplanner.lib.auto;

import com.pathplanner.lib.commands.*;
import com.pathplanner.lib.config.RobotConfig;
import com.pathplanner.lib.controllers.PathFollowingController;
import com.pathplanner.lib.path.PathConstraints;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.util.GeometryUtil;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj.DriverStation;
import edu.wpi.first.wpilibj.Filesystem;
import edu.wpi.first.wpilibj.smartdashboard.SendableChooser;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Commands;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.ArrayList;
import java.util.List;
import java.util.function.*;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

/** Utility class used to build auto routines */
public class AutoBuilder {
  private static boolean configured = false;

  private static Function<PathPlannerPath, Command> pathFollowingCommandBuilder;
  private static Consumer<Pose2d> resetPose;
  private static BooleanSupplier shouldFlipPath;

  // Pathfinding builders
  private static boolean pathfindingConfigured = false;
  private static TriFunction<Pose2d, PathConstraints, Double, Command> pathfindToPoseCommandBuilder;
  private static BiFunction<PathPlannerPath, PathConstraints, Command>
      pathfindThenFollowPathCommandBuilder;

  /**
   * Configures the AutoBuilder for using PathPlanner's built-in commands.
   *
   * @param poseSupplier a supplier for the robot's current pose
   * @param resetPose a consumer for resetting the robot's pose
   * @param robotRelativeSpeedsSupplier a supplier for the robot's current robot relative chassis
   *     speeds
   * @param robotRelativeOutput a consumer for setting the robot's robot-relative chassis speeds
   * @param controller Path following controller that will be used to follow paths
   * @param robotConfig The robot configuration
   * @param shouldFlipPath Supplier that determines if paths should be flipped to the other side of
   *     the field. This will maintain a global blue alliance origin.
   * @param driveRequirements the subsystem requirements for the robot's drive train
   */
  public static void configure(
      Supplier<Pose2d> poseSupplier,
      Consumer<Pose2d> resetPose,
      Supplier<ChassisSpeeds> robotRelativeSpeedsSupplier,
      Consumer<ChassisSpeeds> robotRelativeOutput,
      PathFollowingController controller,
      RobotConfig robotConfig,
      BooleanSupplier shouldFlipPath,
      Subsystem... driveRequirements) {
    if (configured) {
      DriverStation.reportError(
          "Auto builder has already been configured. This is likely in error.", true);
    }

    AutoBuilder.pathFollowingCommandBuilder =
        (path) ->
            new FollowPathCommand(
                path,
                poseSupplier,
                robotRelativeSpeedsSupplier,
                robotRelativeOutput,
                controller,
                robotConfig,
                shouldFlipPath,
                driveRequirements);
    AutoBuilder.resetPose = resetPose;
    AutoBuilder.configured = true;
    AutoBuilder.shouldFlipPath = shouldFlipPath;

    AutoBuilder.pathfindToPoseCommandBuilder =
        (pose, constraints, goalEndVel) ->
            new PathfindingCommand(
                pose,
                constraints,
                goalEndVel,
                poseSupplier,
                robotRelativeSpeedsSupplier,
                robotRelativeOutput,
                controller,
                robotConfig,
                driveRequirements);
    AutoBuilder.pathfindThenFollowPathCommandBuilder =
        (path, constraints) ->
            new PathfindThenFollowPath(
                path,
                constraints,
                poseSupplier,
                robotRelativeSpeedsSupplier,
                robotRelativeOutput,
                controller,
                robotConfig,
                shouldFlipPath,
                driveRequirements);
    AutoBuilder.pathfindingConfigured = true;
  }

  /**
   * Configures the AutoBuilder with custom path following command builder. Building pathfinding
   * commands is not supported if using a custom command builder. Custom path following commands
   * will not have the path flipped for them, and event markers will not be triggered automatically.
   *
   * @param pathFollowingCommandBuilder a function that builds a command to follow a given path
   * @param resetPose a consumer for resetting the robot's pose
   * @param shouldFlipPose Supplier that determines if the starting pose should be flipped to the
   *     other side of the field. This will maintain a global blue alliance origin. NOTE: paths will
   *     not be flipped when configured with a custom path following command. Flipping the paths
   *     must be handled in your command.
   */
  public static void configureCustom(
      Function<PathPlannerPath, Command> pathFollowingCommandBuilder,
      Consumer<Pose2d> resetPose,
      BooleanSupplier shouldFlipPose) {
    if (configured) {
      DriverStation.reportError(
          "Auto builder has already been configured. This is likely in error.", true);
    }

    AutoBuilder.pathFollowingCommandBuilder = pathFollowingCommandBuilder;
    AutoBuilder.resetPose = resetPose;
    AutoBuilder.configured = true;
    AutoBuilder.shouldFlipPath = shouldFlipPose;

    AutoBuilder.pathfindingConfigured = false;
  }

  /**
   * Configures the AutoBuilder with custom path following command builder. Building pathfinding
   * commands is not supported if using a custom command builder. Custom path following commands
   * will not have the path flipped for them, and event markers will not be triggered automatically.
   *
   * @param pathFollowingCommandBuilder a function that builds a command to follow a given path
   * @param resetPose a consumer for resetting the robot's pose
   */
  public static void configureCustom(
      Function<PathPlannerPath, Command> pathFollowingCommandBuilder, Consumer<Pose2d> resetPose) {
    configureCustom(pathFollowingCommandBuilder, resetPose, () -> false);
  }

  /**
   * Returns whether the AutoBuilder has been configured.
   *
   * @return true if the AutoBuilder has been configured, false otherwise
   */
  public static boolean isConfigured() {
    return configured;
  }

  /**
   * Returns whether the AutoBuilder has been configured for pathfinding.
   *
   * @return true if the AutoBuilder has been configured for pathfinding, false otherwise
   */
  public static boolean isPathfindingConfigured() {
    return pathfindingConfigured;
  }

  /**
   * Builds a command to follow a path. PathPlannerLib commands will also trigger event markers
   * along the way.
   *
   * @param path the path to follow
   * @return a path following command with for the given path
   * @throws AutoBuilderException if the AutoBuilder has not been configured
   */
  public static Command followPath(PathPlannerPath path) {
    if (!isConfigured()) {
      throw new AutoBuilderException(
          "Auto builder was used to build a path following command before being configured");
    }

    return pathFollowingCommandBuilder.apply(path);
  }

  /**
   * Build a command to pathfind to a given pose. If not using a holonomic drivetrain, the pose
   * rotation and rotation delay distance will have no effect.
   *
   * @param pose The pose to pathfind to
   * @param constraints The constraints to use while pathfinding
   * @param goalEndVelocity The goal end velocity of the robot when reaching the target pose
   * @return A command to pathfind to a given pose
   */
  public static Command pathfindToPose(
      Pose2d pose, PathConstraints constraints, double goalEndVelocity) {
    if (!isPathfindingConfigured()) {
      throw new AutoBuilderException(
          "Auto builder was used to build a pathfinding command before being configured");
    }

    return pathfindToPoseCommandBuilder.apply(pose, constraints, goalEndVelocity);
  }

  /**
   * Build a command to pathfind to a given pose. If not using a holonomic drivetrain, the pose
   * rotation will have no effect.
   *
   * @param pose The pose to pathfind to
   * @param constraints The constraints to use while pathfinding
   * @return A command to pathfind to a given pose
   */
  public static Command pathfindToPose(Pose2d pose, PathConstraints constraints) {
    return pathfindToPose(pose, constraints, 0);
  }

  /**
   * Build a command to pathfind to a given pose that will be flipped based on the value of the path
   * flipping supplier when this command is run. If not using a holonomic drivetrain, the pose
   * rotation and rotation delay distance will have no effect.
   *
   * @param pose The pose to pathfind to. This will be flipped if the path flipping supplier returns
   *     true
   * @param constraints The constraints to use while pathfinding
   * @param goalEndVelocity The goal end velocity of the robot when reaching the target pose
   * @return A command to pathfind to a given pose
   */
  public static Command pathfindToPoseFlipped(
      Pose2d pose, PathConstraints constraints, double goalEndVelocity) {
    return Commands.either(
        pathfindToPose(GeometryUtil.flipFieldPose(pose), constraints, goalEndVelocity),
        pathfindToPose(pose, constraints, goalEndVelocity),
        shouldFlipPath);
  }

  /**
   * Build a command to pathfind to a given pose that will be flipped based on the value of the path
   * flipping supplier when this command is run. If not using a holonomic drivetrain, the pose
   * rotation and rotation delay distance will have no effect.
   *
   * @param pose The pose to pathfind to. This will be flipped if the path flipping supplier returns
   *     true
   * @param constraints The constraints to use while pathfinding
   * @return A command to pathfind to a given pose
   */
  public static Command pathfindToPoseFlipped(Pose2d pose, PathConstraints constraints) {
    return pathfindToPoseFlipped(pose, constraints, 0);
  }

  /**
   * Build a command to pathfind to a given path, then follow that path. If not using a holonomic
   * drivetrain, the pose rotation delay distance will have no effect.
   *
   * @param goalPath The path to pathfind to, then follow
   * @param pathfindingConstraints The constraints to use while pathfinding
   * @return A command to pathfind to a given path, then follow the path
   */
  public static Command pathfindThenFollowPath(
      PathPlannerPath goalPath, PathConstraints pathfindingConstraints) {
    if (!isPathfindingConfigured()) {
      throw new AutoBuilderException(
          "Auto builder was used to build a pathfinding command before being configured");
    }

    return pathfindThenFollowPathCommandBuilder.apply(goalPath, pathfindingConstraints);
  }

  /**
   * Create and populate a sendable chooser with all PathPlannerAutos in the project. The default
   * option will be Commands.none()
   *
   * @return SendableChooser populated with all autos
   */
  public static SendableChooser<Command> buildAutoChooser() {
    return buildAutoChooser("");
  }

  /**
   * Create and populate a sendable chooser with all PathPlannerAutos in the project
   *
   * @param defaultAutoName The name of the auto that should be the default option. If this is an
   *     empty string, or if an auto with the given name does not exist, the default option will be
   *     Commands.none()
   * @return SendableChooser populated with all autos
   */
  public static SendableChooser<Command> buildAutoChooser(String defaultAutoName) {
    return buildAutoChooserWithOptionsModifier(defaultAutoName, (stream) -> stream);
  }

  /**
   * Create and populate a sendable chooser with all PathPlannerAutos in the project. The default
   * option will be Commands.none()
   *
   * @param optionsModifier A lambda function that can be used to modify the options before they go
   *     into the AutoChooser
   * @return SendableChooser populated with all autos
   */
  public static SendableChooser<Command> buildAutoChooserWithOptionsModifier(
      Function<Stream<PathPlannerAuto>, Stream<PathPlannerAuto>> optionsModifier) {
    return buildAutoChooserWithOptionsModifier("", optionsModifier);
  }

  /**
   * Create and populate a sendable chooser with all PathPlannerAutos in the project
   *
   * @param defaultAutoName The name of the auto that should be the default option. If this is an
   *     empty string, or if an auto with the given name does not exist, the default option will be
   *     Commands.none()
   * @param optionsModifier A lambda function that can be used to modify the options before they go
   *     into the AutoChooser
   * @return SendableChooser populated with all autos
   */
  public static SendableChooser<Command> buildAutoChooserWithOptionsModifier(
      String defaultAutoName,
      Function<Stream<PathPlannerAuto>, Stream<PathPlannerAuto>> optionsModifier) {
    if (!AutoBuilder.isConfigured()) {
      throw new RuntimeException(
          "AutoBuilder was not configured before attempting to build an auto chooser");
    }

    SendableChooser<Command> chooser = new SendableChooser<>();
    List<String> autoNames = getAllAutoNames();

    PathPlannerAuto defaultOption = null;
    List<PathPlannerAuto> options = new ArrayList<>();

    for (String autoName : autoNames) {
      PathPlannerAuto auto = new PathPlannerAuto(autoName);

      if (!defaultAutoName.isEmpty() && defaultAutoName.equals(autoName)) {
        defaultOption = auto;
      } else {
        options.add(auto);
      }
    }

    if (defaultOption == null) {
      chooser.setDefaultOption("None", Commands.none());
    } else {
      chooser.setDefaultOption(defaultOption.getName(), defaultOption);
    }

    optionsModifier
        .apply(options.stream())
        .forEach(auto -> chooser.addOption(auto.getName(), auto));

    return chooser;
  }

  /**
   * Get a list of all auto names in the project
   *
   * @return List of all auto names
   */
  public static List<String> getAllAutoNames() {
    File[] autoFiles = new File(Filesystem.getDeployDirectory(), "pathplanner/autos").listFiles();

    if (autoFiles == null) {
      return new ArrayList<>();
    }

    return Stream.of(autoFiles)
        .filter(file -> !file.isDirectory())
        .map(File::getName)
        .filter(name -> name.endsWith(".auto"))
        .map(name -> name.substring(0, name.lastIndexOf(".")))
        .collect(Collectors.toList());
  }

  /**
   * Get the starting pose from its JSON representation. This is only used internally.
   *
   * @param startingPoseJson JSON object representing a starting pose.
   * @return The Pose2d starting pose
   */
  public static Pose2d getStartingPoseFromJson(JSONObject startingPoseJson) {
    JSONObject pos = (JSONObject) startingPoseJson.get("position");
    double x = ((Number) pos.get("x")).doubleValue();
    double y = ((Number) pos.get("y")).doubleValue();
    double deg = ((Number) startingPoseJson.get("rotation")).doubleValue();

    return new Pose2d(x, y, Rotation2d.fromDegrees(deg));
  }

  /**
   * Builds an auto command for the given auto name.
   *
   * @param autoName the name of the auto to build
   * @return an auto command for the given auto name
   */
  public static Command buildAuto(String autoName) {
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
      return getAutoCommandFromJson(json);
    } catch (Exception e) {
      throw new RuntimeException(String.format("Error building auto: %s", autoName), e);
    }
  }

  /**
   * Builds an auto command from the given JSON object.
   *
   * @param autoJson the JSON object to build the command from
   * @return an auto command built from the JSON object
   */
  public static Command getAutoCommandFromJson(JSONObject autoJson) {
    JSONObject commandJson = (JSONObject) autoJson.get("command");
    boolean choreoAuto = autoJson.get("choreoAuto") != null && (boolean) autoJson.get("choreoAuto");

    Command autoCommand = CommandUtil.commandFromJson(commandJson, choreoAuto);
    if (autoJson.get("startingPose") != null) {
      Pose2d startPose = getStartingPoseFromJson((JSONObject) autoJson.get("startingPose"));
      return Commands.sequence(
          Commands.runOnce(
              () -> {
                boolean flip = shouldFlipPath.getAsBoolean();
                if (flip) {
                  resetPose.accept(GeometryUtil.flipFieldPose(startPose));
                } else {
                  resetPose.accept(startPose);
                }
              }),
          autoCommand);
    } else {
      return autoCommand;
    }
  }

  /** Functional interface for a function that takes 3 inputs */
  @FunctionalInterface
  public interface TriFunction<In1, In2, In3, Out> {
    /**
     * Apply the inputs to this function
     *
     * @param in1 Input 1
     * @param in2 Input 2
     * @param in3 Input 3
     * @return Output
     */
    Out apply(In1 in1, In2 in2, In3 in3);
  }
}
