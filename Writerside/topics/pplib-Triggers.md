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