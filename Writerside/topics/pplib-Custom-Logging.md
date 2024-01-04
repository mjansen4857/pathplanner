# Custom Logging

PathPlannerLib provides the ability to set custom logging callbacks that will be called when the built-in path following
commands are running. You can set these callbacks through the `PathPlannerLogging` class.

These can be used for logging path following data with logging frameworks such
as [AdvantageKit](https://github.com/Mechanical-Advantage/AdvantageKit), or visualization with
a [Field2d Widget](https://docs.wpilib.org/en/stable/docs/software/dashboards/glass/field2d-widget.html).

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
public class RobotContainer {
    private final Field2d field;
    
    public RobotContainer(){
        field = new Field2d();
        SmartDashboard.putData("Field", field);

        // Logging callback for current robot pose
        PathPlannerLogging.setLogCurrentPoseCallback((pose) -> {
            // Do whatever you want with the pose here
            field.setRobotPose(pose);
        });

        // Logging callback for target robot pose
        PathPlannerLogging.setLogTargetPoseCallback((pose) -> {
            // Do whatever you want with the pose here
            field.getObject("target pose").setPose(pose);
        });

        // Logging callback for the active path, this is sent as a list of poses
        PathPlannerLogging.setLogActivePathCallback((poses) -> {
            // Do whatever you want with the poses here
            field.getObject("path").setPoses(poses);
        });
    }
}
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <frc/smartdashboard/Field2d.h>
#include <frc/smartdashboard/SmartDashboard.h>
#include <pathplanner/lib/util/PathPlannerLogging.h>

using namespace pathplanner;

frc::Field2d m_field;

RobotContainer() {
    frc::SmartDashboard::PutData("Field", &m_field);
    
    // Logging callback for current robot pose
    PathPlannerLogging::setLogCurrentPoseCallback([this](frc::Pose2d pose) -> {
        // Do whatever you want with the pose here
        m_field.SetRobotPose(pose);
    });
    
    // Logging callback for target robot pose
    PathPlannerLogging::setLogTargetPoseCallback([this](frc::Pose2d pose) -> {
        // Do whatever you want with the pose here
        m_field.GetObject("target pose").setPose(pose);
    });
    
    // Logging callback for the active path, this is sent as a vector of poses
    PathPlannerLogging::setLogActivePathCallback([this](std::vector<frc::Pose2d> poses) -> {
        // Do whatever you want with the poses here
        m_field.GetObject("path").setPoses(poses);
    });
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.logging import PathPlannerLogging
from wpilib import Field2d, SmartDashboard

field = Field2d()
SmartDashboard.putData('Field', field)

# Logging callback for current robot pose
PathPlannerLogging.setLogCurrentPoseCallback(lambda pose: field.setRobotPose(pose))

# Logging callback for target robot pose
PathPlannerLogging.setLogTargetPoseCallback(lambda pose: field.getObject('target pose').setPose(pose))

# Logging callback for the active path, this is sent as a list of poses
PathPlannerLogging.setLogActivePathCallback(lambda poses: field.getObject('path').setPoses(poses))
```

</tab>
</tabs>