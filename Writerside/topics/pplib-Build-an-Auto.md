# Build an Auto

<snippet id="build-an-auto">
## Configure AutoBuilder

In PathPlannerLib, AutoBuilder is used to create full autonomous routines based on auto files created in the GUI app. In
order for AutoBuilder to be able to build these auto routines, it must first be configured to control your robot.

There are a few options for configuring AutoBuilder, one for each type of path following command: Holonomic, Ramsete,
and LTV.

> **Note**
>
> Since all of the AutoBuilder configuration is related to the drive subsystem, it is recommended to configure
> AutoBuilder within your drive subsystem's constructor.
>
{style="note"}

The following examples will assume that your drive subsystem has the following methods:

* `getPose` - Returns the current robot pose as a `Pose2d`
* `resetPose` - Resets the robot's odometry to the given pose
* `getRobotRelativeSpeeds` or `getCurrentSpeeds` - Returns the current robot-relative `ChassisSpeeds`. This can be
  calculated using one of
  WPILib's drive kinematics classes
* `driveRobotRelative` or `drive` - Outputs commands to the robot's drive motors given robot-relative `ChassisSpeeds`.
  This can be
  converted to module states or wheel speeds using WPILib's drive kinematics classes.

> **Warning**
>
> The AutoBuilder configuration requires a method that will return true when a path should be flipped to the red side of
> the field. The origin of the field coordinate system will remain on the blue side.
>
> If you wish to have any other alliance color based transformation, you must implement it yourself by changing the data
> passed to, and received from, PathPlannerLib's path following commands.
>
{style="warning"}

### Holonomic (Swerve)

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
public class DriveSubsystem extends SubsystemBase {
    public DriveSubsystem() {
        // All other subsystem initialization
        // ...

        // Configure AutoBuilder last
        AutoBuilder.configureHolonomic(
                this::getPose, // Robot pose supplier
                this::resetPose, // Method to reset odometry (will be called if your auto has a starting pose)
                this::getRobotRelativeSpeeds, // ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
                this::driveRobotRelative, // Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds
                new HolonomicPathFollowerConfig( // HolonomicPathFollowerConfig, this should likely live in your Constants class
                        new PIDConstants(5.0, 0.0, 0.0), // Translation PID constants
                        new PIDConstants(5.0, 0.0, 0.0), // Rotation PID constants
                        4.5, // Max module speed, in m/s
                        0.4, // Drive base radius in meters. Distance from robot center to furthest module.
                        new ReplanningConfig() // Default path replanning config. See the API for the options here
                ),
                () -> {
                    // Boolean supplier that controls when the path will be mirrored for the red alliance
                    // This will flip the path being followed to the red side of the field.
                    // THE ORIGIN WILL REMAIN ON THE BLUE SIDE

                    var alliance = DriverStation.getAlliance();
                    if (alliance.isPresent()) {
                        return alliance.get() == DriverStation.Alliance.Red;
                    }
                    return false;
                },
                this // Reference to this subsystem to set requirements
        );
    }
}
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/auto/AutoBuilder.h>
#include <pathplanner/lib/util/HolonomicPathFollowerConfig.h>
#include <pathplanner/lib/util/PIDConstants.h>
#include <pathplanner/lib/util/ReplanningConfig.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/DriverStation.h>

using namespace pathplanner;

SwerveSubsystem::SwerveSubsystem(){
    // Do all subsystem initialization here
    // ...

    // Configure the AutoBuilder last
    AutoBuilder::configureHolonomic(
        [this](){ return getPose(); }, // Robot pose supplier
        [this](frc::Pose2d pose){ resetPose(pose); }, // Method to reset odometry (will be called if your auto has a starting pose)
        [this](){ return getRobotRelativeSpeeds(); }, // ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
        [this](frc::ChassisSpeeds speeds){ driveRobotRelative(speeds); }, // Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds
        HolonomicPathFollowerConfig( // HolonomicPathFollowerConfig, this should likely live in your Constants class
            PIDConstants(5.0, 0.0, 0.0), // Translation PID constants
            PIDConstants(5.0, 0.0, 0.0), // Rotation PID constants
            4.5_mps, // Max module speed, in m/s
            0.4_m, // Drive base radius in meters. Distance from robot center to furthest module.
            ReplanningConfig() // Default path replanning config. See the API for the options here
        ),
        []() {
            // Boolean supplier that controls when the path will be mirrored for the red alliance
            // This will flip the path being followed to the red side of the field.
            // THE ORIGIN WILL REMAIN ON THE BLUE SIDE

            auto alliance = DriverStation::GetAlliance();
            if (alliance) {
                return alliance.value() == DriverStation::Alliance::kRed;
            }
            return false;
        },
        this // Reference to this subsystem to set requirements
    );
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.auto import AutoBuilder
from pathplannerlib.config import HolonomicPathFollowerConfig, ReplanningConfig, PIDConstants
from wpilib import DriverStation

class SwerveSubsystem(Subsystem):
    def __init__(self):
        # Do all subsystem initialization here
        # ...

        # Configure the AutoBuilder last
        AutoBuilder.configureHolonomic(
            self.getPose, # Robot pose supplier
            self.resetPose, # Method to reset odometry (will be called if your auto has a starting pose)
            self.getRobotRelativeSpeeds, # ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
            self.driveRobotRelative, # Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds
            HolonomicPathFollowerConfig( # HolonomicPathFollowerConfig, this should likely live in your Constants class
                PIDConstants(5.0, 0.0, 0.0), # Translation PID constants
                PIDConstants(5.0, 0.0, 0.0), # Rotation PID constants
                4.5, # Max module speed, in m/s
                0.4, # Drive base radius in meters. Distance from robot center to furthest module.
                ReplanningConfig() # Default path replanning config. See the API for the options here
            ),
            self.shouldFlipPath, # Supplier to control path flipping based on alliance color
            self # Reference to this subsystem to set requirements
        )
    
    def shouldFlipPath():
        # Boolean supplier that controls when the path will be mirrored for the red alliance
        # This will flip the path being followed to the red side of the field.
        # THE ORIGIN WILL REMAIN ON THE BLUE SIDE
        return DriverStation.getAlliance() == DriverStation.Alliance.kRed
```

</tab>
</tabs>

### Ramsete (Differential)

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
public class DriveSubsystem extends SubsystemBase {
    public DriveSubsystem() {
        // All other subsystem initialization
        // ...

        // Configure AutoBuilder last
        AutoBuilder.configureRamsete(
                this::getPose, // Robot pose supplier
                this::resetPose, // Method to reset odometry (will be called if your auto has a starting pose)
                this::getCurrentSpeeds, // Current ChassisSpeeds supplier
                this::drive, // Method that will drive the robot given ChassisSpeeds
                new ReplanningConfig(), // Default path replanning config. See the API for the options here
                () -> {
                    // Boolean supplier that controls when the path will be mirrored for the red alliance
                    // This will flip the path being followed to the red side of the field.
                    // THE ORIGIN WILL REMAIN ON THE BLUE SIDE

                    var alliance = DriverStation.getAlliance();
                    if (alliance.isPresent()) {
                        return alliance.get() == DriverStation.Alliance.Red;
                    }
                    return false;
                },
                this // Reference to this subsystem to set requirements
        );
    }
}
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/auto/AutoBuilder.h>
#include <pathplanner/lib/util/ReplanningConfig.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>

using namespace pathplanner;

DriveSubsystem::DriveSubsystem(){
    // Do all subsystem initialization here
    // ...

    // Configure the AutoBuilder last
    AutoBuilder::configureRamsete(
        [this](){ return getPose(); }, // Robot pose supplier
        [this](frc::Pose2d pose){ resetPose(pose); }, // Method to reset odometry (will be called if your auto has a starting pose)
        [this](){ return getRobotRelativeSpeeds(); }, // ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
        [this](frc::ChassisSpeeds speeds){ driveRobotRelative(speeds); }, // Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds
        ReplanningConfig(), // Default path replanning config. See the API for the options here
        []() {
            // Boolean supplier that controls when the path will be mirrored for the red alliance
            // This will flip the path being followed to the red side of the field.
            // THE ORIGIN WILL REMAIN ON THE BLUE SIDE

            auto alliance = DriverStation::GetAlliance();
            if (alliance) {
                return alliance.value() == DriverStation::Alliance::kRed;
            }
            return false;
        },
        this // Reference to this subsystem to set requirements
    );
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.auto import AutoBuilder
from pathplannerlib.config import ReplanningConfig, PIDConstants

class DriveSubsystem(Subsystem):
    def __init__(self):
        # Do all subsystem initialization here
        # ...

        # Configure the AutoBuilder last
        AutoBuilder.configureRamsete(
            self.getPose, # Robot pose supplier
            self.resetPose, # Method to reset odometry (will be called if your auto has a starting pose)
            self.getCurrentSpeeds, # Current ChassisSpeeds supplier
            self.drive, # Method that will drive the robot given ChassisSpeeds
            ReplanningConfig(), # Default path replanning config. See the API for the options here
            self.shouldFlipPath, # Supplier to control path flipping based on alliance color
            self # Reference to this subsystem to set requirements
        )
    
    def shouldFlipPath():
        # Boolean supplier that controls when the path will be mirrored for the red alliance
        # This will flip the path being followed to the red side of the field.
        # THE ORIGIN WILL REMAIN ON THE BLUE SIDE
        return DriverStation.getAlliance() == DriverStation.Alliance.kRed
```

</tab>
</tabs>

### LTV (Differential)

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
public class DriveSubsystem extends SubsystemBase {
    public DriveSubsystem() {
        // All other subsystem initialization
        // ...

        // Configure AutoBuilder last
        AutoBuilder.configureLTV(
                this::getPose, // Robot pose supplier
                this::resetPose, // Method to reset odometry (will be called if your auto has a starting pose)
                this::getCurrentSpeeds, // Current ChassisSpeeds supplier
                this::drive, // Method that will drive the robot given ChassisSpeeds
                0.02, // Robot control loop period in seconds. Default is 0.02
                new ReplanningConfig(), // Default path replanning config. See the API for the options here
                () -> {
                    // Boolean supplier that controls when the path will be mirrored for the red alliance
                    // This will flip the path being followed to the red side of the field.
                    // THE ORIGIN WILL REMAIN ON THE BLUE SIDE

                    var alliance = DriverStation.getAlliance();
                    if (alliance.isPresent()) {
                        return alliance.get() == DriverStation.Alliance.Red;
                    }
                    return false;
                },
                this // Reference to this subsystem to set requirements
        );
    }
}
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/auto/AutoBuilder.h>
#include <pathplanner/lib/util/ReplanningConfig.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>

using namespace pathplanner;

DriveSubsystem::DriveSubsystem(){
    // Do all subsystem initialization here
    // ...

    // Configure the AutoBuilder last
    AutoBuilder::configureLTV(
        [this](){ return getPose(); }, // Robot pose supplier
        [this](frc::Pose2d pose){ resetPose(pose); }, // Method to reset odometry (will be called if your auto has a starting pose)
        [this](){ return getRobotRelativeSpeeds(); }, // ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
        [this](frc::ChassisSpeeds speeds){ driveRobotRelative(speeds); }, // Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds
        0.02_s, // Robot control loop period in seconds. Default is 0.02
        ReplanningConfig(), // Default path replanning config. See the API for the options here
        []() {
            // Boolean supplier that controls when the path will be mirrored for the red alliance
            // This will flip the path being followed to the red side of the field.
            // THE ORIGIN WILL REMAIN ON THE BLUE SIDE

            auto alliance = DriverStation::GetAlliance();
            if (alliance) {
                return alliance.value() == DriverStation::Alliance::kRed;
            }
            return false;
        },
        this // Reference to this subsystem to set requirements
    );
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.auto import AutoBuilder
from pathplannerlib.config import ReplanningConfig, PIDConstants

class DriveSubsystem(Subsystem):
    def __init__(self):
        # Do all subsystem initialization here
        # ...

        # Configure the AutoBuilder last
        AutoBuilder.configureLTV(
            self.getPose, # Robot pose supplier
            self.resetPose, # Method to reset odometry (will be called if your auto has a starting pose)
            self.getCurrentSpeeds, # Current ChassisSpeeds supplier
            self.drive, # Method that will drive the robot given ChassisSpeeds
            (0.0625, 0.125, 2.0), # qelems/error tolerances
            (1.0, 2.0), # relems/control effort
            0.02, # Robot control loop period in seconds. Default is 0.02
            ReplanningConfig(), # Default path replanning config. See the API for the options here
            self.shouldFlipPath, # Supplier to control path flipping based on alliance color
            self # Reference to this subsystem to set requirements
        )
    
    def shouldFlipPath():
        # Boolean supplier that controls when the path will be mirrored for the red alliance
        # This will flip the path being followed to the red side of the field.
        # THE ORIGIN WILL REMAIN ON THE BLUE SIDE
        return DriverStation.getAlliance() == DriverStation.Alliance.kRed
```

</tab>
</tabs>

## Load an Auto

After you have configured the AutoBuilder, creating an auto is as simple as constructing a `PathPlannerAuto` with the
name of the auto you made in the GUI.

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
public class RobotContainer {
    // ...

    public Command getAutonomousCommand() {
        return new PathPlannerAuto("Example Auto");
    }
}
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/commands/PathPlannerAuto.h>

using namespace pathplanner;

frc2::CommandPtr RobotContainer::getAutonomousCommand(){
    return PathPlannerAuto("Example Auto").ToPtr();
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.auto import PathPlannerAuto

class RobotContainer:
    def getAutonomousCommand():
        return PathPlannerAuto('Example Auto')

```

</tab>
</tabs>

## Create a SendableChooser with all autos in project

> **Note**
>
> This feature is only available in the Java version of PathPlannerLib
>
{style="note"}

After configuring the AutoBuilder, you have the option to build a SendableChooser that is automatically populated with
every auto in the project.

```Java
public class RobotContainer {
    private final SendableChooser<Command> autoChooser;

    public RobotContainer() {
        // ...

        // Build an auto chooser. This will use Commands.none() as the default option.
        autoChooser = AutoBuilder.buildAutoChooser();

        // Another option that allows you to specify the default auto by its name
        // autoChooser = AutoBuilder.buildAutoChooser("My Default Auto");

        SmartDashboard.putData("Auto Chooser", autoChooser);
    }

    public Command getAutonomousCommand() {
        return autoChooser.getSelected();
    }
}
```

</snippet>