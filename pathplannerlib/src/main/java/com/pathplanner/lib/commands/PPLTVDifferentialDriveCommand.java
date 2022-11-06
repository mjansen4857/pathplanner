package com.pathplanner.lib.commands;

import com.pathplanner.lib.PathPlannerTrajectory;
import com.pathplanner.lib.server.PathPlannerServer;
import edu.wpi.first.math.controller.DifferentialDriveWheelVoltages;
import edu.wpi.first.math.controller.LTVDifferentialDriveController;
import edu.wpi.first.math.controller.LTVUnicycleController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.kinematics.DifferentialDriveWheelSpeeds;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj.smartdashboard.Field2d;
import edu.wpi.first.wpilibj.smartdashboard.SmartDashboard;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.CommandBase;
import edu.wpi.first.wpilibj2.command.Subsystem;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.function.Consumer;
import java.util.function.Supplier;

public class PPLTVDifferentialDriveCommand extends CommandBase {
    private final Timer timer = new Timer();
    private final PathPlannerTrajectory trajectory;
    private final Supplier<Pose2d> poseSupplier;
    private final Supplier<DifferentialDriveWheelSpeeds> speedsSupplier;
    private final Consumer<DifferentialDriveWheelVoltages> output;
    private final LTVDifferentialDriveController controller;
    private final HashMap<String, Command> eventMap;

    private final Field2d field = new Field2d();
    private ArrayList<PathPlannerTrajectory.EventMarker> unpassedMarkers;

    /**
     * Creates a new PPLTVDifferentialDriveCommand. This command will follow the given trajectory using an LTVDifferentialDriveController.
     *
     * @param trajectory The trajectory to follow.
     * @param poseSupplier A supplier that returns the current robot pose.
     * @param speedsSupplier A supplier that returns the current robot wheel speeds.
     * @param output A consumer that accepts the output of the controller.
     * @param controller The LTVDifferentialDriveController that will be used to follow the path.
     * @param eventMap A map of event names to commands that will be run when the event is passed.
     * @param requirements The subsystems required by this command.
     */
    public PPLTVDifferentialDriveCommand(PathPlannerTrajectory trajectory, Supplier<Pose2d> poseSupplier, Supplier<DifferentialDriveWheelSpeeds> speedsSupplier, Consumer<DifferentialDriveWheelVoltages> output, LTVDifferentialDriveController controller, HashMap<String, Command> eventMap, Subsystem... requirements) {
        this.trajectory = trajectory;
        this.poseSupplier = poseSupplier;
        this.speedsSupplier = speedsSupplier;
        this.output = output;
        this.controller = controller;
        this.eventMap = eventMap;

        addRequirements(requirements);
    }

    /**
     * Creates a new PPLTVDifferentialDriveCommand. This command will follow the given trajectory using an LTVDifferentialDriveController.
     *
     * @param trajectory The trajectory to follow.
     * @param poseSupplier A supplier that returns the current robot pose.
     * @param speedsSupplier A supplier that returns the current robot wheel speeds.
     * @param output A consumer that accepts the output of the controller.
     * @param controller The LTVDifferentialDriveController that will be used to follow the path.
     * @param requirements The subsystems required by this command.
     */
    public PPLTVDifferentialDriveCommand(PathPlannerTrajectory trajectory, Supplier<Pose2d> poseSupplier, Supplier<DifferentialDriveWheelSpeeds> speedsSupplier, Consumer<DifferentialDriveWheelVoltages> output, LTVDifferentialDriveController controller, Subsystem... requirements) {
        this(trajectory, poseSupplier, speedsSupplier, output, controller, new HashMap<>(), requirements);
    }

    @Override
    public void initialize() {
        this.unpassedMarkers = new ArrayList<>();
        this.unpassedMarkers = new ArrayList<>(this.trajectory.getMarkers());

        SmartDashboard.putData("PPLTVDifferentialDriveCommand_field", this.field);
        this.field.getObject("traj").setTrajectory(this.trajectory);

        PathPlannerServer.sendActivePath(this.trajectory.getStates());

        this.timer.reset();
        this.timer.start();
    }

    @Override
    public void execute() {
        double currentTime = this.timer.get();

        Pose2d currentPose = this.poseSupplier.get();
        DifferentialDriveWheelSpeeds currentSpeeds = this.speedsSupplier.get();
        PathPlannerTrajectory.PathPlannerState desiredState = (PathPlannerTrajectory.PathPlannerState) this.trajectory.sample(currentTime);
        this.field.setRobotPose(currentPose);
        PathPlannerServer.sendPathFollowingData(desiredState.poseMeters, currentPose);

        SmartDashboard.putNumber("PPLTVDifferentialDriveCommand_xError", currentPose.getX() - desiredState.poseMeters.getX());
        SmartDashboard.putNumber("PPLTVDifferentialDriveCommand_yError", currentPose.getY() - desiredState.poseMeters.getY());
        SmartDashboard.putNumber("PPLTVDifferentialDriveCommand_rotationError", currentPose.getRotation().getRadians() - desiredState.poseMeters.getRotation().getRadians());

        this.output.accept(this.controller.calculate(currentPose, currentSpeeds.leftMetersPerSecond, currentSpeeds.rightMetersPerSecond, desiredState));

        if(this.unpassedMarkers.size() > 0 && currentTime >= this.unpassedMarkers.get(0).timeSeconds) {
            PathPlannerTrajectory.EventMarker marker = this.unpassedMarkers.remove(0);

            for(String eventName : marker.names) {
                if(this.eventMap.containsKey(eventName)) {
                    this.eventMap.get(eventName).schedule();
                }
            }
        }
    }

    @Override
    public void end(boolean interrupted) {
        this.timer.stop();

        if (interrupted) {
            this.output.accept(new DifferentialDriveWheelVoltages(0, 0));
        }
    }

    @Override
    public boolean isFinished() {
        return this.timer.hasElapsed(this.trajectory.getTotalTimeSeconds());
    }
}
