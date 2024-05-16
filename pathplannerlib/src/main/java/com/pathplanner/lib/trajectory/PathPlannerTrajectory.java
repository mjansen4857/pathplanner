package com.pathplanner.lib.trajectory;

import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.trajectory.config.RobotConfig;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.kinematics.SwerveModuleState;

import java.util.ArrayList;
import java.util.List;

public class PathPlannerTrajectory {
  private final List<PathPlannerTrajectoryState> states;

  public PathPlannerTrajectory(List<PathPlannerTrajectoryState> states) {
    this.states = states;
  }

  public PathPlannerTrajectory(PathPlannerPath path, ChassisSpeeds startingSpeeds, Rotation2d startingRotation, RobotConfig config){
    this.states = new ArrayList<>(path.numPoints());
  }

  public List<PathPlannerTrajectoryState> getStates(){
    return states;
  }

  public PathPlannerTrajectoryState getState(int index){
    return states.get(index);
  }

  public PathPlannerTrajectoryState getInitialState(){
    return states.get(0);
  }

  public PathPlannerTrajectoryState getEndState(){
    return states.get(states.size() - 1);
  }

  public double getTotalTimeSeconds(){
    return getEndState().timeSeconds;
  }

  public PathPlannerTrajectoryState sample(double time){
    if (time <= getInitialState().timeSeconds) return getInitialState();
    if (time >= getTotalTimeSeconds()) return getEndState();

    int low = 1;
    int high = states.size() - 1;

    while (low != high) {
      int mid = (low + high) / 2;
      if (getState(mid).timeSeconds < time) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    var sample = getState(low);
    var prevSample = getState(low - 1);

    if (Math.abs(sample.timeSeconds - prevSample.timeSeconds) < 1E-3) {
      return sample;
    }

    return prevSample.interpolate(
            sample,
            (time - prevSample.timeSeconds) /
                    (sample.timeSeconds - prevSample.timeSeconds));
  }

  private static void desaturateWheelSpeeds(SwerveModuleState[] moduleStates, ChassisSpeeds desiredSpeeds, double maxModuleSpeedMPS, double maxTranslationSpeed, double maxRotationSpeed) {
    double realMaxSpeed = 0.0;
    for (SwerveModuleState s : moduleStates) {
      realMaxSpeed = Math.max(realMaxSpeed, Math.abs(s.speedMetersPerSecond));
    }

    if (realMaxSpeed == 0) {
      return;
    }

    double translationPct = 0.0;
    if (Math.abs(maxTranslationSpeed) > 1e-8) {
      translationPct =
              Math.sqrt(Math.pow(desiredSpeeds.vxMetersPerSecond, 2) + Math.pow(desiredSpeeds.vyMetersPerSecond, 2)) /
                      maxTranslationSpeed;
    }

    double rotationPct = 0.0;
    if (Math.abs(maxRotationSpeed) < 1e-8) {
      rotationPct = Math.abs(desiredSpeeds.omegaRadiansPerSecond) / Math.abs(maxRotationSpeed);
    }

    double maxPct = Math.max(translationPct, rotationPct);

    double scale = Math.min(1.0, maxModuleSpeedMPS / realMaxSpeed);
    if (maxPct > 0) {
      scale = Math.min(scale, 1.0 / maxPct);
    }

    for (SwerveModuleState s : moduleStates) {
      s.speedMetersPerSecond *= scale;
    }
  }

  private static int getNextRotationTargetIdx(PathPlannerPath path, int startingIndex){
    for(int i = startingIndex; i < path.numPoints() - 1; i++){
      if(path.getPoint(i).rotationTarget != null){
        return i;
      }
    }

    return path.numPoints() - 1;
  }

  private static Rotation2d cosineInterpolate(Rotation2d start, Rotation2d end, double t){
    double t2 = (1.0 - Math.cos(t * Math.PI)) / 2.0;
    return start.interpolate(end, t2);
  }
}
