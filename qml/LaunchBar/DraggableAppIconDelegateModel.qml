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

            LaunchableAppIcon {
                id: launcherIcon

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }

                width: appsVisualDataModel.iconWidth
                iconSize: appsVisualDataModel.iconSize

                appTitle: model.title
                appIcon: model.icon
                appId: model.id
                appParams: model.params === undefined ? "{}" : model.params
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
                onPressAndHold: held = true;
                onReleased: {
                    held = false;

                    // save that layout in DB
                    saveCurrentLayout();
                }
            }

            DropArea {
                anchors { fill: parent; margins: 10 }

                onEntered: {
                    if( drag.source !== launcherIconDelegate ) {
                        appsVisualDataModel.items.move(
                                drag.source.VisualDataModel.itemsIndex,
                                launcherIconDelegate.VisualDataModel.itemsIndex);
                    }
                }
            }
        }
}
