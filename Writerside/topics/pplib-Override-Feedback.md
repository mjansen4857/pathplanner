# Override Feedback

There are some cases where you may wish to override the controller feedback while path following, such as targeting a
game piece. This can be accomplished by providing a function to the `PPHolonomicDriveController` class that will supply
the desired feedback for X position, Y position, or rotation. This is a static method, so it will apply to all path
following commands.

> **Note**
>
> If you supply a method to override the feedback, it will be called every loop. You must make sure to clear the
> feedback override functions when you no longer wish to override the feedback.
>
{style="note"}

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
// Override the X feedback
PPHolonomicDriveController.overrideXFeedback(() -> {
    // Calculate feedback from your custom PID controller
    return 0.0;
});
// Clear the X feedback override
PPHolonomicDriveController.clearXFeedbackOverride();

// Override the Y feedback
PPHolonomicDriveController.overrideYFeedback(() -> {
    // Calculate feedback from your custom PID controller
    return 0.0;
});
// Clear the Y feedback override
PPHolonomicDriveController.clearYFeedbackOverride();

// Override the rotation feedback
PPHolonomicDriveController.overrideRotationFeedback(() -> {
    // Calculate feedback from your custom PID controller
    return 0.0;
});
// Clear the rotation feedback override
PPHolonomicDriveController.clearRotationFeedbackOverride();

// Clear all feedback overrides
PPHolonomicDriveController.clearFeedbackOverrides();
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/controllers/PPHolonomicDriveController.h>

using namespace pathplanner;

// Override the X feedback
PPHolonomicDriveController::overrideXFeedback([]() {
    // Calculate feedback from your custom PID controller
    return 0_mps;
});
// Clear the X feedback override
PPHolonomicDriveController::clearXFeedbackOverride();

// Override the Y feedback
PPHolonomicDriveController::overrideYFeedback([]() {
    // Calculate feedback from your custom PID controller
    return 0_mps;
});
// Clear the Y feedback override
PPHolonomicDriveController::clearYFeedbackOverride();

// Override the rotation feedback
PPHolonomicDriveController::overrideRotationFeedback([]() {
    // Calculate feedback from your custom PID controller
    return 0_rad_per_sec;
});
// Clear the rotation feedback override
PPHolonomicDriveController::clearRotationFeedbackOverride();

// Clear all feedback overrides
PPHolonomicDriveController::clearFeedbackOverrides();
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.controller import PPHolonomicDriveController

# Override the X feedback
PPHolonomicDriveController.overrideXFeedback(lambda: 0.0) # Calculate feedback from your custom PID controller
# Clear the X feedback override
PPHolonomicDriveController.clearXFeedbackOverride()

# Override the Y feedback
PPHolonomicDriveController.overrideYFeedback(lambda: 0.0) # Calculate feedback from your custom PID controller
# Clear the Y feedback override
PPHolonomicDriveController.clearYFeedbackOverride()

# Override the rotation feedback
PPHolonomicDriveController.overrideRotationFeedback(lambda: 0.0) # Calculate feedback from your custom PID controller
# Clear the rotation feedback override
PPHolonomicDriveController.clearRotationFeedbackOverride()

# Clear all feedback overrides
PPHolonomicDriveController.clearFeedbackOverrides()
```

</tab>
</tabs>
