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

    signal startLaunchApplication(string appId, string appParams)

    Drag.active: draggableAppIconItem.draggingActive
    Drag.source: draggableAppIconItem
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    Component.onDestruction: {
        console.log("Bye bye ! I was " + modelTitle + " " + (VisualDataModel.isUnresolved ? "(unresolved)" : "(regular)"));
    }

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
}
