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

            property variant placeHolderItem;

            LaunchableAppIcon {
                id: launcherIcon

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: 5
                    border.color: "lightblue"
                    border.width: 2
                    visible: model.title === ""
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

                    // create a placeHolder for this delegate group
                    createPlaceHolderAt(appsVisualDataModel, launcherIconDelegate.VisualDataModel.itemsIndex);

                    // move our delegate to the persisted items group
                    launcherIconDelegate.VisualDataModel.groups = [ "persistedItems" ];

                    held = true;
                }
                onReleased: {
                    if( held ) {
                        console.log("trigger drop");
                        if( launcherIcon.Drag.target ) {
                            launcherIcon.Drag.drop();
                        }
                        else {
                            // we are not on top of a drop target: fallback.
                            dropAppIcon(launcherIconDelegate);
                        }
                        held = false;

                        if( launcherIconDelegate.placeHolderItem ) {
                            launcherIconDelegate.placeHolderItem.inItems = false;
                            launcherIconDelegate.placeHolderItem = undefined;
                        }
                    }
                }
            }

            DropArea {
                anchors { fill: parent; margins: 10 }

                onEntered: {
                    // Do nothing if dragging over the placeHolder item
                    if( !launcherIconDelegate.VisualDataModel.isUnresolved && drag.source !=  launcherIconDelegate  ) {
                        console.log("moving from " + drag.source.placeHolderItem.itemsIndex + " to " + launcherIconDelegate.VisualDataModel.itemsIndex);
                        appsVisualDataModel.items.move(
                                drag.source.placeHolderItem.itemsIndex,
                                launcherIconDelegate.VisualDataModel.itemsIndex);
                    }
                }
                onDropped: {
                    dropAppIcon(drag.source);
                }
            }

            function createPlaceHolderAt(targetAppsVisualDataModel, atIndex)
            {
                if( launcherIconDelegate.placeHolderItem ) {
                    console.log("removing old placeHolder");
                    launcherIconDelegate.placeHolderItem.inItems = false;
                    launcherIconDelegate.placeHolderItem = undefined;
                }
                targetAppsVisualDataModel.items.insert(atIndex, {title: "", icon: "", id: ""});
                launcherIconDelegate.placeHolderItem = targetAppsVisualDataModel.items.get(atIndex);
                launcherIconDelegate.placeHolderItem.sourceProperties = {
                     title: launcherIconDelegate.modelTitle,
                     icon: launcherIconDelegate.modelIcon,
                     id: launcherIconDelegate.modelId,
                     params: launcherIconDelegate.modelParams
                };
                launcherIconDelegate.placeHolderItem.appsVisualDataModel = targetAppsVisualDataModel;

                console.log("placeHolderItemIndex = " + atIndex + ", launcherIconDelegate.placeHolderItem = " + launcherIconDelegate.placeHolderItem);
            }

            function dropAppIcon(sourceDrag)
            {
                console.log("=== drop === ");

                // replace the placeHolder with ourself
                var placeHolderItemsIndex = sourceDrag.placeHolderItem.itemsIndex;
                var placeHolderVisualDataModel = sourceDrag.placeHolderItem.appsVisualDataModel;

                console.log("placeHolderItemsIndex ="+placeHolderItemsIndex);
                if( sourceDrag.VisualDataModel.model === placeHolderVisualDataModel ) {
                    // same tab
                    console.log("move dragged icon from = " + sourceDrag.VisualDataModel.itemsIndex);
                    sourceDrag.VisualDataModel.inItems = true;
                    placeHolderVisualDataModel.items.move(sourceDrag.VisualDataModel.itemsIndex, placeHolderItemsIndex);
                    console.log("moved dragged icon to = " + sourceDrag.VisualDataModel.itemsIndex);

                    // save that layout in DB (it will save the whole launcher)
                    placeHolderVisualDataModel.saveCurrentLayout();
                }
                else {
                    // different tab
                    placeHolderVisualDataModel.items.insert(placeHolderItemsIndex, {
                                                         title: sourceDrag.placeHolderItem.sourceProperties.title,
                                                         id: sourceDrag.placeHolderItem.sourceProperties.id,
                                                         icon: sourceDrag.placeHolderItem.sourceProperties.icon,
                                                         params: sourceDrag.placeHolderItem.sourceProperties.params });

                    // save that layout in DB (it will save the whole launcher)
                    placeHolderVisualDataModel.saveCurrentLayout();
                    sourceDrag.VisualDataModel.model.saveCurrentLayout();
                }

                sourceDrag.VisualDataModel.inPersistedItems = false;
            }
        }
}
