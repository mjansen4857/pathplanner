# Override Target Rotation

There are some cases where you may wish to override the target rotation while path following, such as targeting a game
piece. This can be accomplished by providing a function to the `PPHolonomicDriveController` class that will supply an
optional rotation override. This is a static method, so it will apply to all path following commands.

> **Note**
>
> If you supply a method to override the rotation target, it will be called every loop. You must make sure to return an
> empty optional when you do not wish to override the rotation.
>
{style="note"}

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
public SwerveSubsystem(){
    // ... other initialization

    // Set the method that will be used to get rotation overrides
    PPHolonomicDriveController.setRotationTargetOverride(this::getRotationTargetOverride);
}

public Optional<Rotation2d> getRotationTargetOverride(){
    // Some condition that should decide if we want to override rotation
    if(Limelight.hasGamePieceTarget()) {
        // Return an optional containing the rotation override (this should be a field relative rotation)
        return Optional.of(Limelight.getRobotToGamePieceRotation());
    } else {
        // return an empty optional when we don't want to override the path's rotation
        return Optional.empty();
    }
}
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/controllers/PPHolonomicDriveController.h>

using namespace pathplanner;

SwerveSubsystem::SwerveSubsystem(){
    // ... other initialization

    // Set the method that will be used to get rotation overrides
    PPHolonomicDriveController::setRotationTargetOverride([this](){ return getRotationTargetOverride(); });
}

std::optional<frc::Rotation2d> SwerveSubsystem::getRotationTargetOverride(){
    // Some condition that should decide if we want to override rotation
    if(Limelight::hasGamePieceTarget()) {
        // Return the rotation override (this should be a field relative rotation)
        return Limelight::getRobotToGamePieceRotation();
    } else {
        // return an empty optional when we don't want to override the path's rotation
        return std::nullopt;
    }
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.controller import PPHolonomicDriveController
from wpimath.geometry import Rotation2d

class SwerveSubsystem(Subsystem):
    def __init__(self):
        # ... other initialization

        # Set the method that will be used to get rotation overrides
        PPHolonomicDriveController.setRotationTargetOverride(self.getRotationTargetOverride);

    def getRotationTargetOverride(self) -> Rotation2d:
        # Some condition that should decide if we want to override rotation
        if Limelight.hasGamePieceTarget():
            # Return the rotation override (this should be a field relative rotation)
            return Limelight.getRobotToGamePieceRotation()
        else:
            # return None when we don't want to override the path's rotation
            return None
```

</tab>
</tabs>
