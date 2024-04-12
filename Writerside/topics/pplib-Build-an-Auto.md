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

> **Warning**
>
> It is highly recommended to create all of your autos when code starts, instead of creating them when you want to run
> them. Large delays can happen when loading complex autos/paths, so it is best to load them before they are needed.
>
> In the interest of simplicity, this example will show an auto being loaded in the `getAutonomousCommand` function,
> which is called when auto is enabled. This is not the recommended way to load your autos.
>
{style="warning"}

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

After configuring the AutoBuilder, you have the option to build a SendableChooser that is automatically populated with
every auto in the project.

> **Warning**
>
> This method will load all autos in the deploy directory. Since the deploy process does not automatically clear the
> deploy directory, old auto files that have since been deleted from the project could remain on the RIO, therefore
> being
> added to the auto chooser.
>
> To remove old options, the deploy directory will need to be cleared manually via SSH, WinSCP, reimaging the RIO, etc.
>
{style="warning"}

<tabs group="pplib-language">
<tab title="Java" group-key="java">

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

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/auto/AutoBuilder.h>
#include <frc/smartdashboard/SmartDashboard.h>
#include <frc2/command/CommandPtr.h>
#include <frc2/command/Command.h>
#include <memory>

using namespace pathplanner;

RobotContainer::RobotContainer() {
  // ...

  // Build an auto chooser. This will use frc2::cmd::None() as the default option.
  autoChooser = AutoBuilder::buildAutoChooser();

  // Another option that allows you to specify the default auto by its name
  // autoChooser = AutoBuilder::buildAutoChooser("My Default Auto");

  frc::SmartDashboard::PutData("Auto Chooser", &autoChooser);
}

frc2::Command* RobotContainer::getAutonomousCommand() {
  // Returns a frc2::Command* that is freed at program termination
  return autoChooser.GetSelected();
}

frc2::CommandPtr RobotContainer::getAutonomousCommand() {
  // Returns a copy that is freed after reference is lost
  return frc2::CommandPtr(std::make_unique<frc2::Command>(*autoChooser.GetSelected()));
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.auto import AutoBuilder

class RobotContainer:
    
    def __init__():

        # Build an auto chooser. This will use Commands.none() as the default option.
        self.autoChooser = AutoBuilder.buildAutoChooser()
        
        # Another option that allows you to specify the default auto by its name
        # self.autoChooser = AutoBuilder.buildAutoChooser("My Default Auto")
        
        SmartDashboard.putData("Auto Chooser", self.autoChooser)
    
    def getAutonomousCommand():
        return self.autoChooser.getSelected()
```

</tab>
</tabs>

## Create a SendableChooser with certain autos in project

> **Note**
>
> This feature is unavailable in the Python version of PathPlannerLib
>
{style="note"}

You can use the buildAutoChooserWithOptionsModifier method to process the 
autos before they are shown on shuffle board

> **Warning**
>
> Be careful using runtime values when generating AutoChooser, as RobotContainer is 
> built at robot code startup. Things like FMS values may not be present at startup
>
{style="warning"}

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```java
public class RobotContainer {
  private final SendableChooser<Command> autoChooser;

  public RobotContainer() {
    // ...

    // For convenience a programmer could change this when going to competition.
    boolean isCompetition = true;
    
    // Build an auto chooser. This will use Commands.none() as the default option.
    // As an example, this will only show autos that start with "comp" while at
    // competition as defined by the programmer
    autoChooser = AutoBuilder.buildAutoChooserWithOptionsModifier(
      (stream) -> isCompetition
        ? stream.filter(auto -> auto.getName().startsWith("comp")) 
        : stream
    );

    SmartDashboard.putData("Auto Chooser", autoChooser);
  }

  public Command getAutonomousCommand() {
    return autoChooser.getSelected();
  }
}
```
</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/auto/AutoBuilder.h>
#include <frc/smartdashboard/SmartDashboard.h>
#include <frc2/command/CommandPtr.h>
#include <frc2/command/Command.h>
#include <memory>

using namespace pathplanner;

RobotContainer::RobotContainer() {
  // ...

  // For convenience a programmer could change this when going to competition.
  bool isCompetition = true;
    
  // Build an auto chooser. This will use frc2::cmd::None() as the default option.
  // Default option is skipped, filtering will not result in "None" being removed.
  // As an example, this will only show autos that start with "comp" while at
  // competition as defined by the programmer
  autoChooser = AutoBuilder.buildAutoChooser("",
    [isCompetition](PathPlannerAuto* cmdPtr) {
      if(isCompetition)
      {
        return cmdPtr->GetName().starts_with("comp");
      }
      return true;
    }
  );

  // Another option that allows you to specify the default auto by its name.
  // Default option is skipped, so "My Default Auto" is guaranteed to be 
  // in SendableChooser, even though it fails when filtered.
  // autoChooser = AutoBuilder::buildAutoChooser("My Default Auto",
  //   [isCompetition](PathPlannerAuto* cmdPtr) {
  //     if(isCompetition)
  //     {
  //       return cmdPtr->GetName().starts_with("comp");
  //     }
  //     return true;
  //   }
  // );

  frc::SmartDashboard::PutData("Auto Chooser", &autoChooser);
}

frc2::Command* RobotContainer::getAutonomousCommand() {
  // Returns a frc2::Command* that is freed at program termination
  return autoChooser.GetSelected();
}

frc2::CommandPtr RobotContainer::getAutonomousCommand() {
  // Returns a copy that is freed after reference is lost
  return frc2::CommandPtr(std::make_unique<frc2::Command>(*autoChooser.GetSelected()));
}
```

</tab>
</tabs>

</snippet>
