# Settings

The settings menu can be accessed via the [Navigation Menu](gui-Navigation-Menu.md)

<img src="settings.png" alt="settings" border-effect="rounded"/>

## Robot Config

Bumper Width
: The width of the robot, including bumpers, in meters. Used for visualization.

Bumper Length
: The length of the robot, including bumpers, in meters. Used for visualization.

Robot Mass
: The mass of the robot, including bumpers and battery, in Kilograms.

Robot MOI
: The Moment of Inertia, or MOI, of the robot, including battery and bumpers. This can be calculated via CAD software,
or calculated by applying a constant torque to all drive motors and measuring the angular acceleration of the robot.

Wheelbase
: The distance between the front and back of the drivebase, in meters. Only relevant in holonomic mode.

Trackwidth
: The distance between the left and right sides of the drivebase, in meters.

## Module Config

Wheel Radius
: The radius of the drive wheels, in meters.

Drive Gearing
: The gear reduction from the motors to the wheels.

True Max Drive Speed
: The true maximum speed of the robot/drive module while driving under load, in meters/second.

Wheel COF
: The coefficient of friction between the drive wheels and the carpet. Some wheels will have their COF listed on their
store page. The COF of friction can also be calculated by measuring how much force is required to pull the robot (
causing the wheels to slide) across the carpet. You can also tune this number until the wheels no longer slip while
accelerating or turning in corners.

Drive Motor
: The type of motor used to drive the wheels of the robot.

Drive Current Limit
: The supply current limit applied to the drive motor controllers, in Amps. Below this field, the Max Optimal Limit is
displayed, which is the maximum usable current limit that prevents the wheels from slipping. This is calculated based on
other configuration options.

## Default Constraints

These values will be used as the default global constraints when creating new paths. Updating these values will also
update the constraints of any paths set to use the defaults.

The default constraints do not support being unlimited, as a conscious decision should be made per-path to have
unlimited constraints. Running a path as fast as possible is not only dangerous, but can lead to the path following
controller falling behind.

Max Velocity
: Max linear velocity in meters per second.

Max Acceleration
: Max linear acceleration in meters per second squared.

Max Angular Velocity
: Max rotational velocity in degrees per second.

Max Angular Accel
: Max rotational acceleration in degrees per second squared.

## Field Image

Select the field image used as the background of the editor. This contains options for official field images and the
ability to import custom images.

## Theme Color

Change the UI theme color.

## PPLib Telemetry

Host
: The host address of the robot for use in telemetry and hot reload. If running simulation, this should be `localhost`.
If connected to a robot, this should be the IP address of the roboRIO: `10.TE.AM.2` where TEAM is replaced by your team
number, i.e. `10.30.15.2`.

## Additional Options

Holonomic Mode
: Enable or disable holonomic mode. This is on by default. This must be enabled to access special features for holonomic
drive trains.

Hot Reload
: Enable or disable hot reload for paths and autos. This is off by default. When connected to the robot, hot reload will
automatically sync changes to paths and autos in the GUI to the paths and autos loaded in robot code. This allows you to
quickly iterate and test changes without needing to redeploy or restart robot code. **PLEASE, PLEASE, PLEASE** disable
this at competition, so you don't accidentally change a path on the robot that you do not wish to.

> **Note**
>
> Because the requirements of a command that follows a path with events is set at construction time, the requirements
> cannot be properly updated. If you add or remove named commands in event markers, it is generally a good idea to
> redeploy. Furthermore, if using C++, only paths support hot reload. Autos do not support hot reload in C++ due to
> restrictions of the command library.
>
{style="note"}
