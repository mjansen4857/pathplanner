# Named Commands

You must register your named commands so that they can be used in the creation of Event Markers and Autos. All of your
named commands need to be registered before you create a PathPlanner path or auto in your code. Failure to do so would
mean that any named command registered after path/auto creation will not be used in those paths and autos.

All named commands are registered via static methods in the NamedCommands class. The string used when registering a
command should be identical to the one used in the PathPlanner GUI.

> **Warning**
>
> Named commands must be registered before the creation of any PathPlanner Autos or Paths. It is recommended to do this
> in `RobotContainer`, after subsystem initialization, but before the creation of any other commands.
>
{style="warning"}

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
public class RobotContainer() {
    public RobotContainer() {
        // Subsystem initialization
        swerve = new Swerve();
        exampleSubsystem = new ExampleSubsystem();

        // Register Named Commands
        NamedCommands.registerCommand("autoBalance", swerve.autoBalanceCommand());
        NamedCommands.registerCommand("exampleCommand", exampleSubsystem.exampleCommand());
        NamedCommands.registerCommand("someOtherCommand", new SomeOtherCommand());

        // Do all other initialization
        configureButtonBindings();

        // ...
    }
}
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/auto/NamedCommands.h>
#include <memory>

using namespace pathplanner;

RobotContainer::RobotContainer() : m_swerve(), m_exampleSubsystem() {
    // Register Named Commands. You must pass either a CommandPtr rvalue or a shared_ptr to the command, not the command directly.
    NamedCommands::registerCommand("autoBalance", std::move(m_swerve.autoBalanceCommand())); // <- This example method returns CommandPtr
    NamedCommands::registerCommand("exampleCommand", std::move(m_exampleSubsystem.exampleCommand())); // <- This example method returns CommandPtr
    NamedCommands::registerCommand("someOtherCommand", std::move(SomeOtherCommand().ToPtr()));
    NamedCommands::registerCommand("someOtherCommandShared", std::make_shared<frc2::SomeOtherCommand>());

    // Do all other initialization
    configureButtonBindings();
    
    // ...
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.auto import NamedCommands

class RobotContainer:
    def __init__(self):
        # Subsystem initialization
        self.swerve = Swerve()
        self.exampleSubsystem = ExampleSubsystem()

        # Register Named Commands
        NamedCommands.registerCommand('autoBalance', swerve.autoBalanceCommand())
        NamedCommands.registerCommand('exampleCommand', exampleSubsystem.exampleCommand())
        NamedCommands.registerCommand('someOtherCommand', SomeOtherCommand())

        # Do all other initialization
        self.configureButtonBindings()
    
        # ...
```

</tab>
</tabs>