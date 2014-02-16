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
import LunaNext 0.1

/// The status bar can be divided in three main regions: app menu, title, system indicators/system menu
/// [-- app menu -- |   --- title ---    |  -- indicators --]

Item {
    id: statusBar

    property Item windowManagerInstance
    property bool fullLauncherVisible: false
    property bool justTypeLauncherActive: false

    Rectangle {
        id: coloredBackground
        color: "#2f2f2f"
        visible: false
        anchors.fill: parent
    }

    Image {
        id: background
        anchors.fill: parent
        source: "../images/statusbar/status-bar-background.png"

        Item {
            id: title
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: parent.height * 0.2
            anchors.bottomMargin: parent.height * 0.2
            implicitWidth: titleText.contentWidth

            Text {
                id: titleText
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                color: "white"
                font.family: Settings.fontStatusBar
                font.pixelSize: parent.height;
                font.bold: false
                text: Qt.formatDateTime(new Date(), "dd.MM.yyyy")
            }
        }

        AppMenu {
            id: appMenu
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.topMargin: parent.height * 0.2
            anchors.bottomMargin: parent.height * 0.2
            state: statusBar.state === "application-visible" || launcherInstance.state === "justTypeLauncher" ? "visible" : "hidden"
        }

        SystemIndicators {
            id: systemIndicators
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
        }
    }

    function switchBackgroundParent(value) {
        if (value) {
            coloredBackground.visible = true;
            background.parent = coloredBackground;
        }
        else {
            coloredBackground.visible = false;
            background.parent = statusBar;
        }
    }

    state: "default"

    states: [
        State {
            name: "hidden"
            PropertyChanges { target: statusBar; visible: false }
        },
        State {
            name: "default"
            PropertyChanges { target: statusBar; visible: true }
        },
        State {
            name: "application-visible"
            PropertyChanges { target: statusBar; visible: true }

        }
    ]

    Connections {
        target: windowManagerInstance
        onSwitchToDashboard: {
            state = "default";
        }
        onSwitchToMaximize: {
            state = "application-visible";
            switchBackgroundParent(true);
        }
        onSwitchToFullscreen: {
            state = "hidden";
            switchBackgroundParent(true);
        }
        onSwitchToCardView: {
            state = "default";
            switchBackgroundParent(false);
        }
        onSwitchToLauncherView: {
            state = "default";
            switchBackgroundParent(true);
        }
    }
}
