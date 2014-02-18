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
    id: statusBarItem

    property Item windowManagerInstance
    property bool fullLauncherVisible: false

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
            id: titleItem
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
                font.bold: true
                text: Qt.formatDateTime(new Date(), "dd.MM.yyyy")
            }
        }

        /// app menu/cellular network provider
        Loader {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.topMargin: parent.height * 0.2
            anchors.bottomMargin: parent.height * 0.2

            Component {
                id: networkNameComponent
                Item { }
            }

            Component {
                id: appMenuComponent
                StatusBarAppMenu {
                    id: appMenuItem
                }
            }

            sourceComponent: statusBarItem.state === "appSpecific" ? appMenuComponent : networkNameComponent
        }

        /// system indicators
        SystemIndicators {
            id: systemIndicatorsStatusBarItem

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
            background.parent = statusBarItem;
        }
    }

    state: "genericStatus"

    states: [
        State {
            name: "hidden"
            PropertyChanges { target: statusBarItem; visible: false }
        },
        State {
            name: "genericStatus"
            PropertyChanges { target: statusBarItem; visible: true }
        },
        State {
            name: "appSpecific"
            PropertyChanges { target: statusBarItem; visible: true }
        }
    ]

    Connections {
        target: windowManagerInstance
        onSwitchToDashboard: {
            state = "genericStatus";
        }
        onSwitchToMaximize: {
            state = "appSpecific";
            switchBackgroundParent(true);
        }
        onSwitchToFullscreen: {
            state = "hidden";
            switchBackgroundParent(true);
        }
        onSwitchToCardView: {
            state = "genericStatus";
            switchBackgroundParent(false);
        }
        onSwitchToLauncherView: {
            state = "appSpecific";
            switchBackgroundParent(true);
        }
    }
}
