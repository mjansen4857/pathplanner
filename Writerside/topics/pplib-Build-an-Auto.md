# Build an Auto

<snippet id="build-an-auto">
## Configure AutoBuilder

In PathPlannerLib, AutoBuilder is used to create full autonomous routines based on auto files created in the GUI app. In
order for AutoBuilder to be able to build these auto routines, it must first be configured to control your robot.

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
  This can be converted to module states or wheel speeds using WPILib's drive kinematics classes.

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
    
    // Load the RobotConfig from the GUI settings. You should probably
    // store this in your Constants file
    RobotConfig config;
    try{
      config = RobotConfig.fromGUISettings();
    } catch (Exception e) {
      // Handle exception as needed
      e.printStackTrace();
    }

    // Configure AutoBuilder last
    AutoBuilder.configure(
            this::getPose, // Robot pose supplier
            this::resetPose, // Method to reset odometry (will be called if your auto has a starting pose)
            this::getRobotRelativeSpeeds, // ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
            (speeds, feedforwards) -> driveRobotRelative(speeds), // Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds. Also optionally outputs individual module feedforwards
            new PPHolonomicDriveController( // PPHolonomicController is the built in path following controller for holonomic drive trains
                    new PIDConstants(5.0, 0.0, 0.0), // Translation PID constants
                    new PIDConstants(5.0, 0.0, 0.0) // Rotation PID constants
            ),
            config, // The robot configuration
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
#include <pathplanner/lib/config/RobotConfig.h>
#include <pathplanner/lib/controllers/PPHolonomicDriveController.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/DriverStation.h>

using namespace pathplanner;

SwerveSubsystem::SwerveSubsystem(){
    // Do all subsystem initialization here
    // ...
    
    // Load the RobotConfig from the GUI settings. You should probably
    // store this in your Constants file
    RobotConfig config = RobotConfig::fromGUISettings();

    // Configure the AutoBuilder last
    AutoBuilder::configure(
        [this](){ return getPose(); }, // Robot pose supplier
        [this](frc::Pose2d pose){ resetPose(pose); }, // Method to reset odometry (will be called if your auto has a starting pose)
        [this](){ return getRobotRelativeSpeeds(); }, // ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
        [this](auto speeds, auto feedforwards){ driveRobotRelative(speeds); }, // Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds. Also optionally outputs individual module feedforwards
        std::make_shared<PPHolonomicDriveController>( // PPHolonomicController is the built in path following controller for holonomic drive trains
            PIDConstants(5.0, 0.0, 0.0), // Translation PID constants
            PIDConstants(5.0, 0.0, 0.0) // Rotation PID constants
        ),
        config, // The robot configuration
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
from pathplannerlib.controller import PPHolonomicDriveController
from pathplannerlib.config import RobotConfig, PIDConstants
from wpilib import DriverStation

class SwerveSubsystem(Subsystem):
    def __init__(self):
        # Do all subsystem initialization here
        # ...
        
        # Load the RobotConfig from the GUI settings. You should probably
        # store this in your Constants file
        config = RobotConfig.fromGUISettings()

        # Configure the AutoBuilder last
        AutoBuilder.configureHolonomic(
            self.getPose, # Robot pose supplier
            self.resetPose, # Method to reset odometry (will be called if your auto has a starting pose)
            self.getRobotRelativeSpeeds, # ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
            lambda speeds, feedforwards: self.driveRobotRelative(speeds), # Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds. Also outputs individual module feedforwards
            PPHolonomicDriveController( # PPHolonomicController is the built in path following controller for holonomic drive trains
                PIDConstants(5.0, 0.0, 0.0), # Translation PID constants
                PIDConstants(5.0, 0.0, 0.0) # Rotation PID constants
            ),
            config, # The robot configuration
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
    
    // Load the RobotConfig from the GUI settings. You should probably
    // store this in your Constants file
    RobotConfig config;
    try{
      config = RobotConfig.fromGUISettings();
    } catch (Exception e) {
      // Handle exception as needed
      e.printStackTrace();
    }

    // Configure AutoBuilder last
    AutoBuilder.configure(
            this::getPose, // Robot pose supplier
            this::resetPose, // Method to reset odometry (will be called if your auto has a starting pose)
            this::getRobotRelativeSpeeds, // ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
            (speeds, feedforwards) -> driveRobotRelative(speeds), // Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds. Also optionally outputs individual module feedforwards
            new PPLTVController(0.02), // PPLTVController is the built in path following controller for differential drive trains
            config, // The robot configuration
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
#include <pathplanner/lib/config/RobotConfig.h>
#include <pathplanner/lib/controllers/PPLTVController.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/DriverStation.h>

using namespace pathplanner;

DriveSubsystem::DriveSubsystem(){
    // Do all subsystem initialization here
    // ...
    
    // Load the RobotConfig from the GUI settings. You should probably
    // store this in your Constants file
    RobotConfig config = RobotConfig::fromGUISettings();

    // Configure the AutoBuilder last
    AutoBuilder::configure(
        [this](){ return getPose(); }, // Robot pose supplier
        [this](frc::Pose2d pose){ resetPose(pose); }, // Method to reset odometry (will be called if your auto has a starting pose)
        [this](){ return getRobotRelativeSpeeds(); }, // ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
        [this](auto speeds, auto feedforwards){ driveRobotRelative(speeds); }, // Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds. Also optionally outputs individual module feedforwards
        PPLTVController(0.02_s), // PPLTVController is the built in path following controller for differential drive trains
        config, // The robot configuration
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
from pathplannerlib.controller import PPLTVController
from pathplannerlib.config import RobotConfig
from wpilib import DriverStation

class DriveSubsystem(Subsystem):
    def __init__(self):
        # Do all subsystem initialization here
        # ...
        
        # Load the RobotConfig from the GUI settings. You should probably
        # store this in your Constants file
        config = RobotConfig.fromGUISettings()

        # Configure the AutoBuilder last
        AutoBuilder.configureHolonomic(
            self.getPose, # Robot pose supplier
            self.resetPose, # Method to reset odometry (will be called if your auto has a starting pose)
            self.getRobotRelativeSpeeds, # ChassisSpeeds supplier. MUST BE ROBOT RELATIVE
            lambda speeds, feedforwards: self.driveRobotRelative(speeds), # Method that will drive the robot given ROBOT RELATIVE ChassisSpeeds. Also outputs individual module feedforwards
            PPLTVController(0.02), # PPLTVController is the built in path following controller for differential drive trains
            config, # The robot configuration
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
    // This method loads the auto when it is called, however, it is recommended
    // to first load your paths/autos when code starts, then return the
    // pre-loaded auto/path
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
    // This method loads the auto when it is called, however, it is recommended
    // to first load your paths/autos when code starts, then return the
    // pre-loaded auto/path
    return PathPlannerAuto("Example Auto").ToPtr();
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.auto import PathPlannerAuto

class RobotContainer:
    def getAutonomousCommand():
        # This method loads the auto when it is called, however, it is recommended
        # to first load your paths/autos when code starts, then return the
        # pre-loaded auto/path
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
> being added to the auto chooser.
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
> This feature is only available in the Java and C++ versions of PathPlannerLib
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
  // As an example, this will only show autos that start with "comp" while at
  // competition as defined by the programmer
  autoChooser = AutoBuilder::buildAutoChooserFilter(
    [&isCompetition](const PathPlannerAuto& autoCommand)
    {
      return isCompetition ? autoCommand.GetName().starts_with("comp") : true;
    }
  );

  // Another option that allows you to specify the default auto by its name
  /*
  autoChooser = AutoBuilder::buildAutoChooserFilter(
    [&isCompetition](const PathPlannerAuto& autoCommand)
    {
      return isCompetition ? autoCommand.GetName().starts_with("comp") : true;
    },
    "autoDefault", // If filled it will choosen always, regardless of filter
  ); 
  */

  // Another option allows you to filter out current directories relative to deploy/pathplanner/auto directory
  // Allows only autos in directory deploy/pathplanner/autos/comp
  /*
  autoChooser = AutoBuilder::buildAutoChooserFilterPathFilterPath(
    [&isCompetition](const PathPlannerAuto&  autoCommand,
            std::filesystem::path autoPath)
    {
      return isCompetition ? autoPath.compare("comp") > 0 : true;
    }
  ); 
  */

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
