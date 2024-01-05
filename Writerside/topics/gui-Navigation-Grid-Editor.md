# Navigation Grid Editor

![](navgrid.png)

The navigation grid editor is fairly rudimentary in its current state, but it allows editing of the grid that will be
used by PathPlannerLib pathfinding commands to avoid field obstacles. You likely shouldn't need to edit this.

The grid can be edited by either clicking on individual grid nodes to toggle them between an obstacle or a non-obstacle,
or you can click and drag to "paint" multiple nodes. Nodes in red are considered an obstacle.

> **Note**
>
> A grid node should only be considered a non-obstacle if the **center** of the robot can pass through it without hitting an
> obstacle. This is why there is a buffer around obstacles in the default grid.
>
{style="note"}
