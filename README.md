# PathPlanner
![Path Tab](https://i.imgur.com/uKVSTHa.png)
## Working With Paths
![Point Configuration](https://i.imgur.com/kRNfkRt.png)

---
Paths consist of two types of points: anchor and control points. Anchor points are points that *anchor* the path. They are points that the path will pass directly through. Control points are points that are attached to each anchor point. Control points can be used to fine-tune the curve of a path by pulling the path towards it. Anchor points, as well as their corresponding control points, can be added by right clicking anywhere on the field. They can be removed by right clicking on the anchor point that you wish to remove. Any point on the path can be moved by dragging it around, or you can middle-click or ctrl + click on any anchor point to enter a position or change the angle manually. When you are done editing the path, it can be saved and other paths can be loaded with the buttons in the bottom left corner. Your robot settings can be updated or the path can be generated for use on the robot with the buttons in the bottom right corner.

---
## Robot Configuration Variables
![Robot Config Vars](https://i.imgur.com/BVGw8Zy.png)
* **Max Velocity:** Maximum velocity of robot in ft/s
* **Max Acceleration:** Maximum acceleration of robot in ft/s<sup>2</sup>
* **Max Deceleration:** Maximum deceleration of robot in ft/s<sup>2</sup>
* **Wheelbase Width:** The width of the robot's drive train in ft, used for splitting the left and right paths.
* **Time Step:** The amount of time between each point in a profile in seconds
* Settings default to last used values

## Output Configuration Variables
![Output Config Vars](https://i.imgur.com/htVe4WU.png)
* **Path Name:** The name of the path. Underscores are assumed for CSV files and camel case is assumed for arrays
* **Value 1, 2, and 3:** The output values for the path in order. Value choices are: position, velocity, acceleration, time, and none
* **Output Format:** The format that the path is output to. Options are CSV file, Java array, or C++ array. CSV files are saved to a chosen location and arrays are copied to the clipboard
* **Reversed:** Should the robot drive backwards
* Settings default to last used values
