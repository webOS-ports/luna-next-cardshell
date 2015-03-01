/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick 2.0

VisualDataModel {
    id: appsVisualDataModel

    property real iconWidth
    property real iconSize
    property int dragAxis
    property Item dragParent

    signal startLaunchApplication(string appId, string appParams)
    signal saveCurrentLayout()

    delegate:
        Item {
            id: launcherIconDelegate

            height: launcherIcon.height
            width: launcherIcon.width

            property string modelTitle: model.title
            property string modelIcon: model.icon
            property string modelId: model.id
            property string modelParams:  model.params === undefined ? "{}" : model.params

            LaunchableAppIcon {
                id: launcherIcon

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: 5
                    border.color: "lightblue"
                    border.width: 2
                    visible: !model.title || model.title === ""
                }

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }

                width: appsVisualDataModel.iconWidth
                iconSize: appsVisualDataModel.iconSize

                appTitle: launcherIconDelegate.modelTitle
                appIcon: launcherIconDelegate.modelIcon
                appId: launcherIconDelegate.modelId
                appParams: launcherIconDelegate.modelParams === undefined ? "{}" : modelParams
                showTitle: true

                Drag.active: dragArea.held
                Drag.source: launcherIconDelegate
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                glow: dragArea.held

                onStartLaunchApplication: appsVisualDataModel.startLaunchApplication(appId, appParams);

                states: State {
                    when: dragArea.held
                    ParentChange { target: launcherIcon; parent: appsVisualDataModel.dragParent }
                    AnchorChanges {
                        target: launcherIcon
                        anchors { horizontalCenter: undefined; verticalCenter: undefined }
                    }
                }
            }

            MouseArea {
                id: dragArea
                anchors { fill: parent }

                drag.target: held ? launcherIcon : undefined
                drag.axis: appsVisualDataModel.dragAxis

                property bool held: false

                propagateComposedEvents: true
                onPressAndHold: {
                    console.log("=== drag ===");
                    // move our delegate to the persisted items group
                    launcherIconDelegate.VisualDataModel.groups = [ "persistedItems" ];

                    held = true;
                }
                onReleased: {
                    if( held ) {
                        console.log("trigger drop");
                        if( launcherIcon.Drag.target && launcherIcon.Drag.target.placeHolderItem ) {
                            launcherIcon.Drag.drop();
                        }
                        else {
                            console.log("no drop target, resetting drag source");
                            launcherIconDelegate.VisualDataModel.itemsIndex = -1;
                            launcherIconDelegate.VisualDataModel.inItems = true;
                        }

                        held = false;

                        // save that layout in DB
                        launcherIconDelegate.VisualDataModel.model.saveCurrentLayout();

                        launcherIconDelegate.VisualDataModel.inPersistedItems = false;
                    }
                }
            }
        }
}
