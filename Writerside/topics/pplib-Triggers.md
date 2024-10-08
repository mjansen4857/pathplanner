# Triggers

> **Warning**
>
> Due to the nature of Triggers, if you bind a command to an Event Trigger that shares requirements with commands in the
> auto command group, the auto command group will be interrupted when the Event Trigger is triggered.
>
{style="warning"}

## Event Triggers

Event Triggers are used to bind commands to triggers that are tied to event markers. This not only functions as an
alternative to using [](pplib-Named-Commands.md), but allows for more functionality such as:

* Binding different commands to the start/end of a zoned event
* Binding a command to only run while the robot is within a zoned event
* Combine event triggers to run different commands within overlapping zones
* Combine event triggers with other triggers for different functionality depending on outside factors

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
public class RobotContainer() {
    public RobotContainer() {
        // Subsystem initialization
        swerve = new Swerve();
        exampleSubsystem = new ExampleSubsystem();

        new EventTrigger("run intake").whileTrue(Commands.print("running intake"));
        new EventTrigger("shoot note").and(new Trigger(exampleSubsystem::someCondition)).onTrue(Commands.print("shoot note");

        // Do all other initialization
        configureButtonBindings();

        // ...
    }
}
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/events/EventTrigger.h>

using namespace pathplanner;

RobotContainer::RobotContainer() : m_swerve(), m_exampleSubsystem() {
    EventTrigger("run intake").WhileTrue(frc2::cmd::Print("running intake"));
    EventTrigger("shoot note").And(frc2::Trigger([this]() { return m_exampleSubsystem.someCondition(); })).OnTrue(frc2::cmd::Print("shoot note");

    // Do all other initialization
    configureButtonBindings();
    
    // ...
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.events import EventTrigger

class RobotContainer:
    def __init__(self):
        # Subsystem initialization
        self.swerve = Swerve()
        self.exampleSubsystem = ExampleSubsystem()

        EventTrigger('run intake').whileTrue(cmd.print('running intake'))
        EventTrigger('shoot note').and(Trigger(self.exampleSubsystem.someCondition)).onTrue(cmd.print('shoot note')

        # Do all other initialization
        self.configureButtonBindings()
    
        # ...
```

</tab>
</tabs>

## Point Towards Zone Triggers

Point Towards Zone triggers allow you to bind commands to a trigger controlled by the robot entering or leaving a point
towards zone. These triggers use the name of the point towards zone in the GUI to differentiate between zones.

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
public class RobotContainer() {
    public RobotContainer() {
        // Subsystem initialization
        swerve = new Swerve();
        exampleSubsystem = new ExampleSubsystem();

        new PointTowardsZoneTrigger("Speaker").whileTrue(Commands.print("aiming at speaker"));
        
        // Do all other initialization
        configureButtonBindings();

        // ...
    }
}
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/events/PointTowardsZoneTrigger.h>

using namespace pathplanner;

RobotContainer::RobotContainer() : m_swerve(), m_exampleSubsystem() {
    PointTowardsZoneTrigger("Speaker").WhileTrue(frc2::cmd::Print("aiming at speaker"));
    
    // Do all other initialization
    configureButtonBindings();
    
    // ...
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.events import PointTowardsZoneTrigger

class RobotContainer:
    def __init__(self):
        # Subsystem initialization
        self.swerve = Swerve()
        self.exampleSubsystem = ExampleSubsystem()

        PointTowardsZoneTrigger('Speaker').whileTrue(cmd.print('aiming at speaker'))
        
        # Do all other initialization
        self.configureButtonBindings()
    
        # ...
```

</tab>
</tabs>

## PathPlannerAuto Triggers

The PathPlannerAuto command includes a variety of methods to create triggers that are polled by the auto they were
created with. This means that each trigger will only be polled if its associated auto is actually running. Furthermore,
this allows for customization of EventTriggers and PointTowardsZoneTriggers on a per-auto basis.

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
public class RobotContainer() {
    public RobotContainer() {
        // Subsystem initialization
        swerve = new Swerve();
        exampleSubsystem = new ExampleSubsystem();
        
        autoCommand = new PathPlannerAuto("Example Auto");
        // PathPlannerAuto can also be created with a custom command
        // autoCommand = new PathPlannerAuto(new CustomAutoCommand());

        // Bind to different auto triggers
        autoCommand.isRunning().onTrue(Commands.print("Example Auto started"));
        autoCommand.timeElapsed(5).onTrue(Commands.print("5 seconds passed"));
        autoCommand.timeRange(6, 8).whileTrue(Commands.print("between 6 and 8 seconds"));
        autoCommand.event("Example Event Marker").onTrue(Commands.print("passed example event marker"));
        autoCommand.pointTowardsZone("Speaker").onTrue(Commands.print("aiming at speaker"));
        autoCommand.activePath("Example Path").onTrue(Commands.print("started following Example Path"));
        autoCommand.nearFieldPosition(new Translation2d(2, 2), 0.5).whileTrue(Commands.print("within 0.5m of (2, 2)"));
        autoCommand.inFieldArea(new Translation2d(2, 2), new Translation2d(4, 4)).whileTrue(Commands.print("in area of (2, 2) - (4, 4)"));
        
        // Do all other initialization
        configureButtonBindings();

        // ...
    }
}
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/commands/PathPlannerAuto.h>

using namespace pathplanner;

RobotContainer::RobotContainer() : m_swerve(), m_exampleSubsystem() {
    m_autoCommand = PathPlannerAuto("Example Auto");
    // PathPlannerAuto can also be created with a custom command
    // m_autoCommand = PathPlannerAuto(CustomAutoCommand());

    // Bind to different auto triggers
    m_autoCommand.isRunning().OnTrue(frc2::cmd::Print("Example Auto started"));
    m_autoCommand.timeElapsed(5).OnTrue(frc2::cmd::Print("5 seconds passed"));
    m_autoCommand.timeRange(6, 8).WhileTrue(frc2::cmd::Print("between 6 and 8 seconds"));
    m_autoCommand.event("Example Event Marker").OnTrue(frc2::cmd::Print("passed example event marker"));
    m_autoCommand.pointTowardsZone("Speaker").OnTrue(frc2::cmd::Print("aiming at speaker"));
    m_autoCommand.activePath("Example Path").OnTrue(frc2::cmd::Print("started following Example Path"));
    m_autoCommand.nearFieldPosition(Translation2d(2, 2), 0.5).WhileTrue(frc2::cmd::Print("within 0.5m of (2, 2)"));
    m_autoCommand.inFieldArea(Translation2d(2, 2), Translation2d(4, 4)).WhileTrue(frc2::cmd::Print("in area of (2, 2) - (4, 4)"));
    
    // Do all other initialization
    configureButtonBindings();
    
    // ...
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.auto import PathPlannerAuto
import commands2.cmd as cmd

class RobotContainer:
    def __init__(self):
        # Subsystem initialization
        self.swerve = Swerve()
        self.exampleSubsystem = ExampleSubsystem()

        self.autoCommand = PathPlannerAuto("Example Auto")

        // Bind to different auto triggers
        self.autoCommand.isRunning().onTrue(cmd.print_("Example Auto started"));
        self.autoCommand.timeElapsed(5).onTrue(cmd.print_("5 seconds passed"));
        self.autoCommand.timeRange(6, 8).whileTrue(cmd.print_("between 6 and 8 seconds"));
        self.autoCommand.event("Example Event Marker").onTrue(cmd.print_("passed example event marker"));
        self.autoCommand.pointTowardsZone("Speaker").onTrue(cmd.print_("aiming at speaker"));
        self.autoCommand.activePath("Example Path").onTrue(cmd.print_("started following Example Path"));
        self.autoCommand.nearFieldPosition(Translation2d(2, 2), 0.5).whileTrue(cmd.print_("within 0.5m of (2, 2)"));
        self.autoCommand.inFieldArea(Translation2d(2, 2), Translation2d(4, 4)).whileTrue(cmd.print_("in area of (2, 2) - (4, 4)"));
        
        # Do all other initialization
        self.configureButtonBindings()
    
        # ...
```

</tab>
</tabs>
