# Follow a Single Path

## Using AutoBuilder

The easiest way to create a command to follow a single path is by using AutoBuilder.

> **Note**
>
> You must have previously configured AutoBuilder in order to use this option.
> See [Build an Auto](pplib-Build-an-Auto.md)
>
{style="note"}

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
public class RobotContainer {
  public Command getAutonomousCommand() {
    try{
        // Load the path you want to follow using its name in the GUI
        PathPlannerPath path = PathPlannerPath.fromPathFile("Example Path");
        
        // Create a path following command using AutoBuilder. This will also trigger event markers.
        return AutoBuilder.followPath(path);
    } catch (Exception e) {
        DriverStation.reportError("Big oops: " + e.getMessage(), e.getStackTrace());
        return Commands.none();
    }
  }
}
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/path/PathPlannerPath.h>
#include <pathplanner/lib/auto/AutoBuilder.h>

using namespace pathplanner;

frc2::CommandPtr RobotContainer::getAutonomousCommand(){
    // Load the path you want to follow using its name in the GUI
    auto path = PathPlannerPath::fromPathFile("Example Path");

    // Create a path following command using AutoBuilder. This will also trigger event markers.
    return AutoBuilder::followPath(path);
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.path import PathPlannerPath
from pathplannerlib.auto import AutoBuilder

def getAutonomousCommand():
    # Load the path you want to follow using its name in the GUI
    path = PathPlannerPath.fromPathFile('Example Path')

    # Create a path following command using AutoBuilder. This will also trigger event markers.
    return AutoBuilder.followPath(path);
```

</tab>
</tabs>

## Manually Create Path Following Commands

### Holonomic (Swerve)

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
public class DriveSubsystem extends SubsystemBase {
  // Assuming this is a method in your drive subsystem
  public Command followPathCommand(String pathName) {
    try{
        PathPlannerPath path = PathPlannerPath.fromPathFile(pathName);
    
        return new FollowPathCommand(
                path,
                this::getPose, // Robot pose supplier
                this::getRobotRelativeSpeeds, // ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
                this::drive, // Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds, AND feedforwards
                new PPHolonomicDriveController( // PPHolonomicController is the built in path following controller for holonomic drive trains
                        new PIDConstants(5.0, 0.0, 0.0), // Translation PID constants
                        new PIDConstants(5.0, 0.0, 0.0) // Rotation PID constants
                ),
                Constants.robotConfig, // The robot configuration
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
    } catch (Exception e) {
        DriverStation.reportError("Big oops: " + e.getMessage(), e.getStackTrace());
        return Commands.none();
    }
  }
}
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/commands/FollowPathCommand.h>
#include <pathplanner/lib/controllers/PPHolonomicDriveController.h>

using namespace pathplanner;

// Assuming this is a method in your drive subsystem
frc2::CommandPtr  DriveSubsystem::followPathCommand(std::string pathName){
    auto path = PathPlannerPath::fromPathFile(pathName);

    return FollowPathCommand(
        path,
        [this](){ return getPose(); }, // Robot pose supplier
        [this](){ return getRobotRelativeSpeeds(); }, // ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
        [this](frc::ChassisSpeeds speeds, DriveFeedforwards feedforwards){ driveRobotRelative(speeds); }, // Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds, AND feedforwards
        PPHolonomicDriveController( // PPHolonomicController is the built in path following controller for holonomic drive trains
            PIDConstants(5.0, 0.0, 0.0), // Translation PID constants
            PIDConstants(5.0, 0.0, 0.0) // Rotation PID constants
        ),
        Constants::robotConfig, // The robot configuration
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
        { this } // Reference to this subsystem to set requirements
    ).ToPtr();
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.path import PathPlannerPath
from pathplannerlib.commands import FollowPathCommand
from pathplannerlib.controller import PPHolonomicDriveController

# Assuming this is a method in your drive subsystem
def followPathCommand(pathName: str):
    path = PathPlannerPath.fromPathFile(pathName)

    return FollowPathCommand(
        path,
        self.getPose, # Robot pose supplier
        self.getRobotRelativeSpeeds, # ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
        self.driveRobotRelative, # Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds, AND feedforwards
        PPHolonomicDriveController( # PPHolonomicController is the built in path following controller for holonomic drive trains
            PIDConstants(5.0, 0.0, 0.0), # Translation PID constants
            PIDConstants(5.0, 0.0, 0.0) # Rotation PID constants
        ),
        Constants.robotConfig, # The robot configuration
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
  // Assuming this is a method in your drive subsystem
  public Command followPathCommand(String pathName) {
    try{
        PathPlannerPath path = PathPlannerPath.fromPathFile(pathName);
    
        return new FollowPathCommand(
                path,
                this::getPose, // Robot pose supplier
                this::getRobotRelativeSpeeds, // ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
                this::drive, // Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds, AND feedforwards
                new PPLTVController(0.02), // PPLTVController is the built in path following controller for differential drive trains
                Constants.robotConfig, // The robot configuration
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
    } catch (Exception e) {
        DriverStation.reportError("Big oops: " + e.getMessage(), e.getStackTrace());
        return Commands.none();
    }
  }
}
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/commands/FollowPathCommand.h>
#include <pathplanner/lib/controllers/PPLTVController.h>

using namespace pathplanner;

// Assuming this is a method in your drive subsystem
frc2::CommandPtr  DriveSubsystem::followPathCommand(std::string pathName){
    auto path = PathPlannerPath::fromPathFile(pathName);

    return FollowPathCommand(
        path,
        [this](){ return getPose(); }, // Robot pose supplier
        [this](){ return getRobotRelativeSpeeds(); }, // ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
        [this](frc::ChassisSpeeds speeds, DriveFeedforwards feedforwards){ driveRobotRelative(speeds); }, // Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds, AND feedforwards
        PPLTVController(0.02_s), // PPLTVController is the built in path following controller for differential drive trains
        Constants::robotConfig, // The robot configuration
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
        { this } // Reference to this subsystem to set requirements
    ).ToPtr();
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.path import PathPlannerPath
from pathplannerlib.commands import FollowPathCommand
from pathplannerlib.controller import PPLTVController

# Assuming this is a method in your drive subsystem
def followPathCommand(pathName: str):
    path = PathPlannerPath.fromPathFile(pathName)

    return FollowPathCommand(
        path,
        self.getPose, # Robot pose supplier
        self.getRobotRelativeSpeeds, # ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
        self.driveRobotRelative, # Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds, AND feedforwards
        PPLTVController(0.02), # PPLTVController is the built in path following controller for differential drive trains
        Constants.robotConfig, # The robot configuration
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

## Java Warmup

> **Warning**
>
> Due to the nature of how Java works, the first run of a path following command could have a significantly higher delay
> compared with subsequent runs, as all the classes involved will need to be loaded.
>
> To help alleviate this issue, you can run a warmup command in the background when code starts.
>
> This command will not control your robot, it will simply run through a full path following command to warm up the
> library.
>
{style="warning"}

```Java
public void robotInit() {
  // ... all other robot initialization

  FollowPathCommand.warmupCommand().schedule();
}
```
