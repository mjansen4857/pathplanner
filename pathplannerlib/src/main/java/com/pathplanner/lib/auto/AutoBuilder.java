package com.pathplanner.lib.auto;

import com.pathplanner.lib.commands.FollowPathCommand;
import com.pathplanner.lib.commands.FollowPathWithEvents;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.util.PPLibTelemetry;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.wpilibj.Filesystem;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Commands;
import edu.wpi.first.wpilibj2.command.Subsystem;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.Supplier;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

public class AutoBuilder {
  private static boolean configured = false;

  private static Function<PathPlannerPath, Command> pathFollowingCommandBuilder;
  private static Supplier<Pose2d> getPose;
  private static Consumer<Pose2d> resetPose;

  public static void configureHolonomic(
      Supplier<Pose2d> poseSupplier,
      Consumer<Pose2d> resetPose,
      Supplier<ChassisSpeeds> robotRelativeSpeedsSupplier,
      Consumer<ChassisSpeeds> fieldRelativeOutput,
      Subsystem driveSubsystem) {
    if (configured) {
      throw new AutoBuilderException(
          "Auto builder has already been configured. Please only configure auto builder once");
    }

    AutoBuilder.pathFollowingCommandBuilder =
        (path) ->
            new FollowPathCommand(
                path,
                poseSupplier,
                robotRelativeSpeedsSupplier,
                fieldRelativeOutput,
                driveSubsystem);
    AutoBuilder.getPose = poseSupplier;
    AutoBuilder.resetPose = resetPose;
    AutoBuilder.configured = true;
    PPLibTelemetry.setAutoBuilderAvailable(true);
  }

  public static void configureCustom(
      Function<PathPlannerPath, Command> pathFollowingCommandBuilder,
      Supplier<Pose2d> poseSupplier,
      Consumer<Pose2d> resetPose) {
    if (configured) {
      throw new AutoBuilderException(
          "Auto builder has already been configured. Please only configure auto builder once");
    }

    AutoBuilder.pathFollowingCommandBuilder = pathFollowingCommandBuilder;
    AutoBuilder.getPose = poseSupplier;
    AutoBuilder.resetPose = resetPose;
    AutoBuilder.configured = true;
    PPLibTelemetry.setAutoBuilderAvailable(true);
  }

  public static boolean isConfigured() {
    return configured;
  }

  public static Command followPathWithEvents(PathPlannerPath path) {
    if (!isConfigured()) {
      throw new AutoBuilderException(
          "Auto builder was used to build a path following command before being configured");
    }

    return new FollowPathWithEvents(pathFollowingCommandBuilder.apply(path), path, getPose);
  }

  public static Command buildAuto(String autoName) {
    return getAutoCommandFromFile(autoName);
  }

  private static Pose2d getStartingPoseFromJson(JSONObject startingPoseJson) {
    JSONObject pos = (JSONObject) startingPoseJson.get("position");
    double x = ((Number) pos.get("x")).doubleValue();
    double y = ((Number) pos.get("y")).doubleValue();
    double deg = ((Number) startingPoseJson.get("rotation")).doubleValue();

    return new Pose2d(x, y, Rotation2d.fromDegrees(deg));
  }

  private static Command getAutoCommandFromFile(String autoName) {
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
    } catch (AutoBuilderException e) {
      throw e;
    } catch (Exception e) {
      e.printStackTrace();
      return null;
    }
  }

  public static Command getAutoCommandFromJson(JSONObject autoJson) {
    JSONObject commandJson = (JSONObject) autoJson.get("command");

    Command autoCommand = CommandUtil.commandFromJson(commandJson);
    if (autoJson.get("startingPose") != null) {
      Pose2d startPose = getStartingPoseFromJson((JSONObject) autoJson.get("startingPose"));
      return Commands.sequence(Commands.runOnce(() -> resetPose.accept(startPose)), autoCommand);
    } else {
      return autoCommand;
    }
  }
}
