# Project Browser

![](cover.png)

The project browser is the main screen of PathPlanner and allows you to manage your path/auto files as well as open them
for editing. The project browser is split in two, with paths on the left and autos on the right. The relative sizes of
the paths and autos sections can be changed by dragging the handle in between them.

Both paths and autos have independent sorting options, and can both be switched between the default and compact UI
modes. The two icon buttons in the top right of each section allow you to create new folders and paths/autos.

## Path/Auto Cards

![](path_card.png)

The project browser contains a card representing each path and auto in the project. In the default view mode, these
cards will display the full field with a preview of the path or auto.

To edit a path or auto, click on the card to open it in the editor. With a path or auto open, click the back button in
the top left corner to return to the project browser.

To rename a path or auto, click on the name within the card. You can also delete/duplicate it with the dropdown menu in
the top right of the card.

## Folders

![](path_folder.png)

Folders allow for greater organization of your paths/autos within the GUI. To create a folder, click the "add new
folder" button in the top right of the path or auto section to create a path folder or auto folder respectively. Folders
can be renamed by clicking on the name of the folder. To add a path or auto to a folder, simply drag the drop the card
over the folder.

To open a folder, click anywhere on the folder card except for the name. When inside a folder, the "add new folder"
button will change to a "delete folder" button. Deleting a folder will also delete all paths within the folder. Nested
folders are not currently supported. Paths and autos can be removed from a folder by dragging ad dropping them onto
the "root folder" card. The "root folder" card can also be clicked on to return to the root folder.

## Manage Named Commands and Linked Waypoints

In the bottom right hand corner of the project browser is a floating action button that will open the named command and
linked waypoint management menu. Within this menu, you can rename or remove named commands and linked waypoints
throughout all paths and autos in the project without having to manually edit each one. If you delete a named command
that is in use, a warning will be displayed on the path or auto cards that now have an empty named command.
