# PathPlanner
[<img src="https://mjansen4857.github.io/microsoft_store.svg" height="64">](https://microsoft.com/store/apps/9P7HKZQPJH8Q?ocid=badge)
&nbsp;&nbsp;[<img src="https://snapcraft.io/static/images/badges/en/snap-store-black.svg" height="64">](https://snapcraft.io/pathplanner)

Windows and linux verisons can be installed from the Microsoft Store and Snapcraft respectively, or they can be downloaded, along with the MacOS version [here](https://github.com/mjansen4857/PathPlanner/releases/latest)

## What makes PathPlanner different?
![Path Editor](https://i.imgur.com/uiFUST6.png)
PathPlanner is a motion profile generator for FRC robots created by team 3015. Every path allows for manual tuning of the robot position and the curve radius at every point. It allows you to create the perfect path for your robot quicker and easier than other generators. Path Planner can handle more complex paths than other generators because it will slow down the robot as it heads into a turn instead of going through it as fast as possible. Inspiration came from [Vannaka's Generator](https://github.com/vannaka/Motion_Profile_Generator) which uses [Jaci's PathFinder](https://github.com/JacisNonsense/Pathfinder). We used it during the 2018 season but struggled to create complex paths that the robot could follow accurately due to the high speed turns. The program should work on Windows, Mac OS, and Linux. A new update will be released whenever a major problem is fixed or if I've made changes and don't know what to add or fix anymore. ¯\\\_(ツ)\_/¯

## Working With Paths
![Point Configuration](https://i.imgur.com/NFTIRnC.png)
Paths consist of two types of points: anchor and control points. Anchor points are points that *anchor* the path. They are points that the path will pass directly through. Control points are points that are attached to each anchor point. Control points can be used to fine-tune the curve of a path by pulling the path towards it. Anchor points, as well as their corresponding control points, can be added by right clicking anywhere on the field. They can be removed by by control/command + right clicking on the anchor point that you wish to remove. Any point on the path can be moved by dragging it around, or you can right click on any anchor point to enter a position or change the angle manually. Wile holding down the shift key and dragging a control point, its angle will be locked. When you are done editing the path, it can be saved and other paths can be loaded to edit. The path can then be generated for use on the robot or previewed in real time. Your robot settings can be updated using the settings button in the top left corner and other actions can be accessed by hovering over the action button in the bottom right corner. It is assumed that each anchor point represents the center of the robot. This is reflected in the path preview and start/end points.

## Robot Configuration Variables
![Robot Settings](https://i.imgur.com/1BuLEZS.png)
* **Max Velocity:** Maximum velocity of robot in ft/s
* **Max Acceleration:** Maximum acceleration of robot in ft/s<sup>2</sup>
* **Time Step:** The amount of time between each point in a profile in seconds
* **Coefficient of Friction:** The coeficcient of friction between the robot wheels and the floor. This is used to determine the max robot velocity in a curve. Andymark lists the coefficient of friction for most of their wheels on their website. Otherwise, you can try to calculate it yourself, or just tune this value until you find something that works.
* **Wheelbase Width:** The width of the robot's drive train in feet, used for splitting the left and right paths.
* **Robot Length:** The length of the robot from bumper to bumper in feet. This is used to draw the robot in the path preview and at the start/end points of the path

**Settings default to last used values**

## Output Configuration Variables
![Generate Settings](https://i.imgur.com/j3IXm1V.png)
* **Path Name:** The name of the path. Underscores are assumed for CSV files and Python arrays while camel case is assumed for Java and C++ arrays
* **Output Format:** The format that the path is output to. Options are CSV file, Java array, C++ array, or Python array. CSV files are saved to a chosen location and arrays are copied to the clipboard
* **Reversed:** Should the robot drive backwards

**Settings default to last used values**

## How to build manually:
* Install [Node.js](https://nodejs.org)
* Download and unzip this repository
* Run the following in the root directory of this project:
  * `npm install`
  
  * Windows: `npm run build-win`

  * MacOS: `npm run build-mac`

  * Linux: `npm run build-linux`
* The built application will be located in the dist folder

**This app collects anonymous data on feature usage, generation errors, and processing time. [Privacy Policy](https://mjansen4857.github.io/privacy)**
