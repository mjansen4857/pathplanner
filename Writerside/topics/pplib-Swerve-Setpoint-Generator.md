# Swerve Setpoint Generator

Swerve setpoint generator based on a version created by FRC team 254.

Takes a prior setpoint, a desired setpoint, and outputs a new setpoint that respects all the kinematic constraints on
module rotation and wheel velocity/torque, as well as preventing any forces acting on a module's wheel from exceeding
the force of friction.

This improves on the original version in a few ways:

* Module acceleration is limited by the maximum torque its motor can output
* Maximum module torque is limited by friction between the wheels and carpet to prevent wheel slip
* Module rotation is limited to keep its centripetal force under the maximum force of friction to prevent sliding in
  curves
* Friction within the module itself is taken into account, which decreases maximum acceleration but increases maximum
  deceleration

> **Note**
>
> This feature is only available in PathPlannerLib Java. If you would like to see this feature in PPLib C++ or Python,
> feel free to open a pull request to translate it to your language.
>
{style="note"}

```Java
public class SwerveSubsystem extends Subsystem {
    private final SwerveSetpointGenerator setpointGenerator;
    private SwerveSetpoint previousSetpoint;

    public SwerveSubsystem() {
        // All other subsystem initialization
        // ...
        
        // Load the RobotConfig from the GUI settings. You should 
        // probably store this in your Constants file
        RobotConfig config;
        try{
          config = RobotConfig.fromGUISettings();
        } catch (Exception e) {
          // Handle exception as needed
          e.printStackTrace();
        }
        
        setpointGenerator = new SwerveSetpointGenerator(
            config, // The robot configuration. This is the same config used for generating trajectories and running path following commands.
            Units.rotationsToRadians(10.0) // The max rotation velocity of a swerve module in radians per second. This should probably be stored in your Constants file
        );
        
        // Initialize the previous setpoint to the robot's current speeds & module states
        ChassisSpeeds currentSpeeds = getCurrentSpeeds(); // Method to get current robot-relative chassis speeds
        SwerveModuleState[] currentStates = getCurrentModuleStates(); // Method to get the current swerve module states
        previousSetpoint = new SwerveSetpoint(currentSpeeds, currentStates, DriveFeedforwards.zeros(config.numModules));
    }
    
    /**
     * This method will take in desired robot-relative chassis speeds,
     * generate a swerve setpoint, then set the target state for each module
     *
     * @param speeds The desired robot-relative speeds
     */
    public void driveRobotRelative(ChassisSpeeds speeds) {
        // Note: it is important to not discretize speeds before or after
        // using the setpoint generator, as it will discretize them for you
        previousSetpoint = setpointGenerator.generateSetpoint(
            previousSetpoint, // The previous setpoint
            speeds, // The desired target speeds
            0.02 // The loop time of the robot code, in seconds
        );
        setModuleStates(previousSetpoint.moduleStates()); // Method that will drive the robot given target module states
    }
}
```
