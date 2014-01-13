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

import "../LunaSysAPI" as LunaSysAPI

Rectangle {
    id: fullLauncher

    property real iconSize: 64
    property real bottomMargin: 80

    signal startLaunchApplication(string appId, string appParams)

    state: "hidden"
    visible: false
    anchors.top: parent.bottom

    states: [
        State {
            name: "hidden"
            AnchorChanges { target: fullLauncher; anchors.top: parent.bottom; anchors.bottom: undefined }
            PropertyChanges { target: fullLauncher; visible: false }
        },
        State {
            name: "visible"
            AnchorChanges { target: fullLauncher; anchors.top: parent.top; anchors.bottom: parent.bottom }
            PropertyChanges { target: fullLauncher; visible: true }
        }
    ]

    transitions: [
        Transition {
            to: "visible"
            reversible: true

            SequentialAnimation {
                PropertyAction { target: fullLauncher; property: "visible" }
                AnchorAnimation { easing.type:Easing.InOutQuad;  duration: 150 }
            }
        }
    ]

    color: "#2f2f2f"

    LunaSysAPI.ApplicationModel {
        id: appsModel
    }

    GridView {
        id: gridview

        model: appsModel

        function calculateAppIconHMargin(parent, appIconWidth) {
            var nbCellsPerLine = Math.floor(parent.width / (appIconWidth + 10));
            var remainingHSpace = parent.width - nbCellsPerLine * appIconWidth;
            return Math.floor(remainingHSpace / nbCellsPerLine);
        }

        property real appIconWidth: iconSize*1.5
        property real appIconHMargin: calculateAppIconHMargin(parent, appIconWidth)

        cellWidth: appIconWidth + appIconHMargin
        cellHeight: iconSize + iconSize*0.4*2 // we give margin for two lines of text

        width: Math.floor(parent.width / cellWidth) * cellWidth
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: fullLauncher.bottomMargin
        clip: true

        header: Item { height: 30 }
        footer: Item { height: 20 }

        delegate: LaunchableAppIcon {
                width: gridview.appIconWidth

                appTitle: model.title
                appIcon: model.icon
                appId: model.id
                appParams: model.params === undefined ? "{}" : model.params
                showTitle: true

                iconSize: fullLauncher.iconSize

                onStartLaunchApplication: fullLauncher.startLaunchApplication(appId, appParams);
            }
    }
}
