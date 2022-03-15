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
import LunaNext.Common 0.1

Item {
    id: draggableAppIconItem

    property bool editionMode: false
    property bool draggingActive: false

    property alias iconWidth: launcherIcon.width
    property alias iconSize: launcherIcon.iconSize

    property int modelIndex: -1
    property alias modelTitle: launcherIcon.appTitle
    property alias modelIcon: launcherIcon.appIcon
    property alias modelId: launcherIcon.appId
    property alias modelParams:  launcherIcon.appParams
    // default launchPointId can't be removed, see
    //  https://github.com/webOS-ports/luna-appmanager/blob/master/Src/base/application/ApplicationManager.cpp#L2111
    property string modelLaunchPointId: modelId + "_default"
    property bool modelRemovable: false
    property bool modelHideable: false // don't use this right now

    signal startLaunchApplication(string appId, var appParams)
    signal removeAppLauncher(string appId)
    signal hideAppLauncher(string appId)

    Drag.active: draggableAppIconItem.draggingActive
    Drag.source: draggableAppIconItem
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    Image {
        source: Qt.resolvedUrl("../images/launcher/edit-icon-bg.png");
        anchors {
            fill: parent
            margins: 3
        }
        fillMode: Image.Stretch
        visible: draggableAppIconItem.editionMode && !draggingActive
    }

    LaunchableAppIcon {
        id: launcherIcon

        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: 0.5*(launcherIcon.height-draggableAppIconItem.iconSize)-Units.gu(1.4)
        }

        showTitle: true

        glow: draggableAppIconItem.draggingActive

        onStartLaunchApplication: draggableAppIconItem.startLaunchApplication(appId, appParams);
    }

    // App uninstall/remove icon
    Image {
        id: removeAppButton
        property bool highlight: false
        property string iconFile: draggableAppIconItem.modelRemovable ?
                                       ( "edit-button-delete" + (highlight?"-highlight":"")) :
                                       ( "edit-button-remove" + (highlight?"-highlight":""))
        source: Qt.resolvedUrl("../images/launcher/"+iconFile+".png");
        anchors {
            top: parent.top
            right: parent.right
        }
        width: launcherIcon.width*0.4; height: width
        fillMode: Image.PreserveAspectFit
        visible: draggableAppIconItem.editionMode && !draggingActive &&
                 (draggableAppIconItem.modelRemovable || draggableAppIconItem.modelHideable)

        MouseArea {
            anchors.fill: parent
            onClicked: {
                removeAppButton.highlight = true;
                if( draggableAppIconItem.modelRemovable ) {
                    draggableAppIconItem.removeAppLauncher(draggableAppIconItem.modelId);
                }
                else if( draggableAppIconItem.modelHideable ) {
                    draggableAppIconItem.hideAppLauncher(draggableAppIconItem.modelLaunchPointId);
                }
            }
        }
    }
}
