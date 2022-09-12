package com.pathplanner.lib;

import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;

public class PathPoint {
    protected final Translation2d position;
    protected final Rotation2d heading;
    protected final Rotation2d holonomicRotation;
    protected final double velocityOverride;

    public PathPoint(Translation2d position, Rotation2d heading, Rotation2d holonomicRotation, double velocityOverride) {
        this.position = position;
        this.heading = heading;
        this.holonomicRotation = holonomicRotation;
        this.velocityOverride = velocityOverride;
    }

    public PathPoint(Translation2d position, Rotation2d heading, Rotation2d holonomicRotation) {
        this(position, heading, holonomicRotation, -1);
    }

    public PathPoint(Translation2d position, Rotation2d heading, double velocityOverride) {
        this(position, heading, Rotation2d.fromDegrees(0), velocityOverride);
    }

    public PathPoint(Translation2d position, Rotation2d heading) {
        this(position, heading, Rotation2d.fromDegrees(0));
    }
}
